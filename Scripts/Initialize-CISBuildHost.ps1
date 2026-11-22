#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Prepares a Windows build/agent host: installs the pinned Microsoft365DSC version and its
    dependencies, configures WinRM for DSC, checks the authentication certificate and lists
    the Entra app permissions the baseline needs.

.EXAMPLE
    .\Scripts\Initialize-CISBuildHost.ps1 -Tenant Contoso
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [string] $Tenant
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop')
{
    throw 'Run this in Windows PowerShell 5.1 (powershell.exe). Microsoft365DSC compiles and applies configurations there.'
}

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../Build/CISBaseline.psm1') -Force
$root = Get-CISRepositoryRoot
$version = (Import-PowerShellDataFile -Path (Join-Path -Path $root -ChildPath 'Build/RequiredModules.psd1')).Microsoft365DSC
$tenantConfig = Get-CISTenantConfig -Tenant $Tenant

# 1. Module
$installed = Get-Module -ListAvailable -Name Microsoft365DSC | Where-Object { $_.Version -eq [version]$version }
if (-not $installed)
{
    Write-Host "Installing Microsoft365DSC $version ..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-Module -Name Microsoft365DSC -RequiredVersion $version -Scope AllUsers -Force -AllowClobber
}
Import-Module -Name Microsoft365DSC -RequiredVersion $version -Force
Write-Host 'Updating Microsoft365DSC dependencies (this can take several minutes) ...'
Update-M365DSCDependencies

# 2. WinRM / LCM - DSC talks to the local LCM over WinRM; large M365 MOFs need a bigger envelope.
if ((Get-Service -Name WinRM).Status -ne 'Running')
{
    Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
}
Set-Item -Path WSMan:\localhost\MaxEnvelopeSizekb -Value 10000

# 3. Certificate
$thumb = $tenantConfig.Authentication.CertificateThumbprint
$cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $thumb }
if (-not $cert)
{
    Write-Warning "Certificate $thumb is not in Cert:\LocalMachine\My. Import the app's certificate (with private key) before building or deploying."
}
elseif (-not $cert.HasPrivateKey)
{
    Write-Warning "Certificate $thumb has no private key."
}
elseif ($cert.NotAfter -lt (Get-Date).AddDays(30))
{
    Write-Warning "Certificate $thumb expires on $($cert.NotAfter.ToString('yyyy-MM-dd'))."
}
else
{
    Write-Host "Certificate $thumb OK (expires $($cert.NotAfter.ToString('yyyy-MM-dd')))."
}

# 4. Permissions the baseline needs
$resources = Get-CISSettingsFile -Workload (Get-CISWorkload) -Layer @('L1', 'L2', 'L3', 'NG') |
    ForEach-Object { $_.Resources } | ForEach-Object { $_.Resource } | Sort-Object -Unique
Write-Host "`nThe baseline uses $($resources.Count) Microsoft365DSC resources. Required app permissions:"
Get-M365DSCCompiledPermissionList -ResourceNameList $resources -PermissionType Application -AccessType Update |
    Format-List
Write-Host @'
Grant the Graph permissions above to the app registration, and also assign the Entra roles that
Exchange/Teams/SharePoint app-only access needs (Exchange Administrator, Teams Administrator,
SharePoint Administrator, Compliance Administrator - or Global Reader for a drift-only app).
Update-M365DSCAllowedGraphScopes / Update-M365DSCAzureAdApplication can do this for you.
'@
