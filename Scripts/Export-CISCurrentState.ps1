#Requires -Version 5.1
<#
.SYNOPSIS
    Exports the tenant's CURRENT configuration for every resource type the baseline manages.

.DESCRIPTION
    Wraps Export-M365DSCConfiguration with the exact component list used by the baseline.
    Use it:
      * before the first deployment, to see what will change and to capture a rollback point;
      * to find tenant-specific values for tokens (e.g. the EXOExternalInOutlook Identity);
      * as the "source" side of New-M365DSCDeltaReport when you want an HTML diff.

.EXAMPLE
    .\Scripts\Export-CISCurrentState.ps1 -Tenant Contoso

.EXAMPLE
    # HTML diff of current state vs. baseline
    $current = .\Scripts\Export-CISCurrentState.ps1 -Tenant Contoso
    New-M365DSCDeltaReport -Source $current -Destination '.\Output\Contoso\L2+NG\All\CIS_Contoso_All.ps1' -OutputPath .\delta.html
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [string] $Tenant,

    [string] $OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath "../Exports")
)

$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../Build/CISBaseline.psm1') -Force
$tenantConfig = Get-CISTenantConfig -Tenant $Tenant

$workloads = Get-CISWorkload
if ($tenantConfig.ContainsKey('Workloads')) { $workloads = @($tenantConfig.Workloads) }
$components = Get-CISSettingsFile -Workload $workloads -Layer @('L1', 'L2', 'L3', 'NG') |
    ForEach-Object { $_.Resources } | ForEach-Object { $_.Resource } | Sort-Object -Unique

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$folder = Join-Path -Path $OutputPath -ChildPath "$Tenant-$stamp"
New-Item -Path $folder -ItemType Directory -Force | Out-Null

Write-Host "Exporting $($components.Count) components from $($tenantConfig.TenantId) ..."
Export-M365DSCConfiguration -Components $components `
    -ApplicationId $tenantConfig.Authentication.ApplicationId `
    -TenantId $tenantConfig.TenantId `
    -CertificateThumbprint $tenantConfig.Authentication.CertificateThumbprint `
    -Path $folder -FileName 'CurrentState.ps1'

Join-Path -Path $folder -ChildPath 'CurrentState.ps1'
