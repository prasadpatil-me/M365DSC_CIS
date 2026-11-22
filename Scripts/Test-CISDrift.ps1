#Requires -Version 5.1
<#
.SYNOPSIS
    Compares the live tenant with a built baseline - read-only, nothing is changed.

.DESCRIPTION
    Runs Test-DscConfiguration -ReferenceConfiguration against each compiled workload MOF
    (Output/<Tenant>/<Profile>/Workloads/<Workload>/localhost.mof). This evaluates every
    resource's Test() method without touching the LCM's current configuration, so it is safe
    to run on a schedule alongside an applied configuration.

    Writes DriftReport-<timestamp>.csv (one row per resource instance, joined to the CIS
    controls it implements) next to the build and returns the rows.

.EXAMPLE
    .\Scripts\Test-CISDrift.ps1 -BuildPath '.\Output\Contoso\L2+NG'

.EXAMPLE
    .\Scripts\Test-CISDrift.ps1 -BuildPath '.\Output\Contoso\L2+NG' -Workload EntraID, Exchange
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [string] $BuildPath,

    [string[]] $Workload
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop')
{
    throw 'Run this in Windows PowerShell 5.1 (powershell.exe).'
}

$BuildPath = (Resolve-Path -Path $BuildPath).Path
$coverage = Import-Csv -Path (Join-Path -Path $BuildPath -ChildPath 'ControlCoverage.csv')
$workloadRoot = Join-Path -Path $BuildPath -ChildPath 'Workloads'
$dirs = Get-ChildItem -Path $workloadRoot -Directory
if ($Workload) { $dirs = $dirs | Where-Object { $Workload -contains $_.Name } }

$rows = @()
foreach ($dir in $dirs)
{
    $mof = Join-Path -Path $dir.FullName -ChildPath 'localhost.mof'
    if (-not (Test-Path -Path $mof))
    {
        Write-Warning "$($dir.Name): no localhost.mof - build without -SkipCompile first."
        continue
    }

    Write-Host "Testing $($dir.Name) ..."
    $result = Test-DscConfiguration -ReferenceConfiguration $mof -ErrorAction Continue

    $states = @()
    if ($result.ResourcesInDesiredState) { $states += $result.ResourcesInDesiredState | ForEach-Object { [pscustomobject]@{ R = $_; InDesiredState = $true } } }
    if ($result.ResourcesNotInDesiredState) { $states += $result.ResourcesNotInDesiredState | ForEach-Object { [pscustomobject]@{ R = $_; InDesiredState = $false } } }

    foreach ($s in $states)
    {
        # ResourceId looks like: [AADConditionalAccessPolicy]AADConditionalAccessPolicy_CIS_5_2_2_1
        $instance = ($s.R.ResourceId -replace '^\[[^\]]+\]', '')
        $controls = @($coverage | Where-Object { $_.Instance -eq $instance } | ForEach-Object { $_.Control }) -join ', '
        $rows += [pscustomobject]@{
            Workload       = $dir.Name
            Resource       = $s.R.ResourceName
            Instance       = $instance
            Controls       = $controls
            InDesiredState = $s.InDesiredState
            Error          = $s.R.Error
        }
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$report = Join-Path -Path $BuildPath -ChildPath "DriftReport-$stamp.csv"
$rows | Export-Csv -Path $report -NoTypeInformation -Encoding UTF8

$drifted = @($rows | Where-Object { -not $_.InDesiredState })
Write-Host ("{0} resource instances tested, {1} in drift. Report: {2}" -f $rows.Count, $drifted.Count, $report)
if ($drifted.Count -gt 0)
{
    $drifted | Format-Table -Property Workload, Instance, Controls -AutoSize | Out-String | Write-Host
    Write-Host 'For property-level detail run: Test-DscConfiguration -ReferenceConfiguration <mof> -Verbose'
}
$rows
