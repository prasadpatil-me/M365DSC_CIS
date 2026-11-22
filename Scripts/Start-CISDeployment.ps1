#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Applies a built CIS baseline to the tenant (push mode). Changes production settings.

.DESCRIPTION
    By default applies the combined All/localhost.mof, which becomes the LCM's current
    configuration so later Test-DscConfiguration / consistency checks monitor the whole
    baseline. Applying a single -Workload MOF REPLACES the LCM's current configuration with
    that workload only - use it for staged roll-outs, then finish with a full deployment.

    Always runs a drift test first and asks for confirmation (supports -WhatIf / -Confirm).
    Sets the LCM to ApplyAndMonitor so the tenant is not silently re-remediated every 15 min.

.EXAMPLE
    .\Scripts\Start-CISDeployment.ps1 -BuildPath '.\Output\Contoso\L2+NG' -WhatIf

.EXAMPLE
    .\Scripts\Start-CISDeployment.ps1 -BuildPath '.\Output\Contoso\L2+NG' -Workload Teams
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param
(
    [Parameter(Mandatory)]
    [string] $BuildPath,

    [string] $Workload
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop')
{
    throw 'Run this in Windows PowerShell 5.1 (powershell.exe).'
}

$BuildPath = (Resolve-Path -Path $BuildPath).Path
$manifest = Get-Content -Path (Join-Path -Path $BuildPath -ChildPath 'BuildManifest.json') -Raw | ConvertFrom-Json

if ($Workload)
{
    $mofDir = Join-Path -Path $BuildPath -ChildPath "Workloads\$Workload"
    Write-Warning "Applying only '$Workload' replaces the LCM's current configuration with this workload."
}
else
{
    $mofDir = Join-Path -Path $BuildPath -ChildPath 'All'
}
if (-not (Test-Path -Path (Join-Path -Path $mofDir -ChildPath 'localhost.mof')))
{
    throw "No compiled MOF in $mofDir. Build without -SkipCompile first."
}

Write-Host ("Tenant {0} ({1}) - profile {2} - commit {3} - {4} resources" -f
    $manifest.Tenant, $manifest.TenantId, $manifest.Profile, $manifest.Commit, $manifest.ResourcesApplied)

$test = Test-DscConfiguration -ReferenceConfiguration (Join-Path -Path $mofDir -ChildPath 'localhost.mof')
$drift = @($test.ResourcesNotInDesiredState)
Write-Host "$($drift.Count) resource instance(s) will be changed:"
$drift | ForEach-Object { Write-Host "  - $($_.ResourceId)" }

if ($drift.Count -eq 0)
{
    Write-Host 'Tenant already matches the baseline. Nothing to apply.'
    return
}

$target = "$($manifest.Tenant) ($($manifest.TenantId))"
if ($PSCmdlet.ShouldProcess($target, "Apply CIS profile $($manifest.Profile) - $($drift.Count) change(s)"))
{
    [DscLocalConfigurationManager()]
    Configuration CISLcm
    {
        Node localhost
        {
            Settings
            {
                ConfigurationMode  = 'ApplyAndMonitor'
                RefreshMode        = 'Push'
                RebootNodeIfNeeded = $false
            }
        }
    }
    $lcmDir = Join-Path -Path $env:TEMP -ChildPath 'CISLcm'
    CISLcm -OutputPath $lcmDir | Out-Null
    Set-DscLocalConfigurationManager -Path $lcmDir -Force

    Start-DscConfiguration -Path $mofDir -Wait -Force -Verbose
    Write-Host 'Deployment finished. Re-run Test-CISDrift.ps1 to confirm.'
}
