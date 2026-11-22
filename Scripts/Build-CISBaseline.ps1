<#
.SYNOPSIS
    Builds the CIS baseline for a tenant into Output/<Tenant>/<Profile>/.

.DESCRIPTION
    Merges the level layers for each workload, applies the tenant's exceptions, overrides
    and tokens, validates every property against Schema/M365DSC.Schema.json and writes:

      All/CIS_<Tenant>_All.ps1 (+ localhost.mof)          - everything; use for deployment
      Workloads/<Workload>/CIS_<Tenant>_<Workload>.ps1     - one per workload; use for drift tests
      ControlCoverage.csv                                  - control -> resource -> status
      BuildManifest.json                                   - what was built, from which commit

    Compiling MOFs requires Windows PowerShell 5.1 with Microsoft365DSC installed.
    Use -SkipCompile anywhere else (CI, PowerShell 7, Linux/macOS) to generate and validate only.

.EXAMPLE
    .\Scripts\Build-CISBaseline.ps1 -Tenant Contoso
    Builds the level and add-ons defined in Tenants\Contoso\Tenant.psd1.

.EXAMPLE
    .\Scripts\Build-CISBaseline.ps1 -Tenant Contoso -BaseLevel L1 -AddOn @() -Workload Exchange,Teams -SkipCompile
    Generates an L1-only Exchange + Teams configuration without compiling.
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [string] $Tenant,

    [ValidateSet('L1', 'L2', 'L3')]
    [string] $BaseLevel,

    [ValidateSet('NG')]
    [string[]] $AddOn,

    [string[]] $Workload,

    [string] $OutputPath,

    [switch] $SkipCompile,

    [switch] $SkipSchemaValidation,

    [switch] $AllowExpiredExceptions
)

$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../Build/CISBaseline.psm1') -Force

$params = @{} + $PSBoundParameters
Invoke-CISBuild @params
