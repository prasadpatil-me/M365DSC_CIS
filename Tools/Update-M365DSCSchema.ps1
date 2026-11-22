<#
.SYNOPSIS
    Extracts the property schema of Microsoft365DSC (v2+, class-based) resources into
    Schema/M365DSC.Schema.json so the CIS baseline can be validated offline (in CI and
    before every build) against the exact module version you deploy with.

.DESCRIPTION
    Microsoft365DSC 2.x ships class-based DSC resources. Property names, ValidateSet values
    and embedded (complex) classes change between monthly releases - often with
    [BREAKING CHANGE] notes. This script parses the module source with the PowerShell AST
    (nothing is imported or executed) and writes a trimmed schema that contains:

      * every resource referenced by a baseline settings file (or every resource with -All)
      * every MSFT_* complex class those resources use, recursively

    Re-run this whenever you change the pinned Microsoft365DSC version in
    Build/RequiredModules.psd1, then run the Pester tests: any property that was renamed
    or removed will fail validation before it reaches a tenant.

.PARAMETER ModulePath
    Folder of an installed Microsoft365DSC module (e.g.
    'C:\Program Files\WindowsPowerShell\Modules\Microsoft365DSC\2.26.1118.1') or of a
    source checkout (…\Modules\Microsoft365DSC). Defaults to the highest installed version.

.PARAMETER All
    Write the schema for every resource in the module instead of only the referenced ones.

.EXAMPLE
    .\Tools\Update-M365DSCSchema.ps1

.EXAMPLE
    .\Tools\Update-M365DSCSchema.ps1 -ModulePath D:\src\Microsoft365DSC\Modules\Microsoft365DSC
#>
[CmdletBinding()]
param
(
    [string] $ModulePath,

    [switch] $All,

    [string] $OutputFile = (Join-Path -Path $PSScriptRoot -ChildPath '../Schema/M365DSC.Schema.json')
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path

if (-not $ModulePath)
{
    $installed = Get-Module -ListAvailable -Name Microsoft365DSC | Sort-Object -Property Version -Descending | Select-Object -First 1
    if (-not $installed)
    {
        throw 'Microsoft365DSC is not installed. Run Build\Initialize-CISBuildHost.ps1 or pass -ModulePath.'
    }
    $ModulePath = $installed.ModuleBase
}

$manifest = Get-ChildItem -Path $ModulePath -Filter 'Microsoft365DSC.psd1' -File | Select-Object -First 1
$moduleVersion = 'unknown'
if ($manifest)
{
    $moduleVersion = (Import-PowerShellDataFile -Path $manifest.FullName).ModuleVersion
}
Write-Host "Reading Microsoft365DSC $moduleVersion from $ModulePath"

function Get-TypeInfo
{
    param ([System.Management.Automation.Language.ITypeName] $TypeName)

    $name = $TypeName.FullName
    $isArray = $false
    if ($TypeName -is [System.Management.Automation.Language.ArrayTypeName])
    {
        $isArray = $true
        $name = $TypeName.ElementType.FullName
    }
    if ($name -match '^System\.Nullable\[(.+)\]$')
    {
        $name = $Matches[1]
    }
    $name = $name -replace '^System\.', ''
    switch ($name)
    {
        'Boolean' { $name = 'Bool' }
        'UInt32'  { $name = 'Int' }
        'Int32'   { $name = 'Int' }
        'Int64'   { $name = 'Int' }
        'UInt64'  { $name = 'Int' }
        'UInt16'  { $name = 'Int' }
    }
    [ordered]@{ Type = $name; IsArray = $isArray }
}

$resources = @{}
$classes = @{}

$files = Get-ChildItem -Path $ModulePath -Recurse -Filter '*.psm1' -File
foreach ($file in $files)
{
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $errors)
    $typeDefs = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.TypeDefinitionAst] -and $n.IsClass }, $true)

    foreach ($typeDef in $typeDefs)
    {
        $isResource = [bool]($typeDef.Attributes | Where-Object { $_.TypeName.Name -eq 'DscResource' })
        if (-not $isResource -and $typeDef.Name -notlike 'MSFT_*')
        {
            continue
        }

        $props = [ordered]@{}
        foreach ($member in $typeDef.Members)
        {
            if ($member -isnot [System.Management.Automation.Language.PropertyMemberAst] -or $member.IsStatic -or $member.IsHidden)
            {
                continue
            }

            $dscAttr = $member.Attributes | Where-Object { $_.TypeName.Name -eq 'DscProperty' } | Select-Object -First 1
            if ($isResource -and -not $dscAttr)
            {
                continue
            }

            $info = Get-TypeInfo -TypeName $member.PropertyType.TypeName
            $entry = [ordered]@{
                Type    = $info.Type
                IsArray = $info.IsArray
            }
            if ($dscAttr)
            {
                foreach ($arg in $dscAttr.NamedArguments)
                {
                    if ($arg.ArgumentName -in @('Key', 'Mandatory', 'NotConfigurable'))
                    {
                        $entry[$arg.ArgumentName] = $true
                    }
                }
            }

            $validateSet = $member.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' } | Select-Object -First 1
            if ($validateSet)
            {
                $entry.ValidateSet = @($validateSet.PositionalArguments | ForEach-Object { $_.SafeGetValue() })
            }

            $props[$member.Name] = $entry
        }

        if ($isResource)
        {
            $resources[$typeDef.Name] = [ordered]@{ Properties = $props }
        }
        else
        {
            $classes[$typeDef.Name] = [ordered]@{ Properties = $props }
        }
    }
}

Write-Host "Parsed $($resources.Count) resources and $($classes.Count) complex classes."

# Work out which resources to keep.
if ($All)
{
    $keep = @($resources.Keys)
}
else
{
    $keep = @(
        Get-ChildItem -Path (Join-Path -Path $repoRoot -ChildPath 'Baselines') -Recurse -Filter '*.psd1' -File |
            Where-Object { $_.Name -ne 'Levels.psd1' } |
            ForEach-Object { (Import-PowerShellDataFile -Path $_.FullName).Resources } |
            ForEach-Object { $_.Resource } |
            Sort-Object -Unique
    )
}

$outResources = [ordered]@{}
$missing = @()
foreach ($name in ($keep | Sort-Object))
{
    if ($resources.ContainsKey($name))
    {
        $outResources[$name] = $resources[$name]
    }
    else
    {
        $missing += $name
    }
}
if ($missing)
{
    Write-Warning "Referenced resources not found in this module version: $($missing -join ', ')"
}

# Collect complex classes recursively.
$outClasses = [ordered]@{}
$queue = [System.Collections.Generic.Queue[string]]::new()
foreach ($r in $outResources.Values)
{
    foreach ($p in $r.Properties.Values)
    {
        if ($p.Type -like 'MSFT_*') { $queue.Enqueue($p.Type) }
    }
}
while ($queue.Count -gt 0)
{
    $c = $queue.Dequeue()
    if ($outClasses.Contains($c) -or -not $classes.ContainsKey($c)) { continue }
    $outClasses[$c] = $classes[$c]
    foreach ($p in $classes[$c].Properties.Values)
    {
        if ($p.Type -like 'MSFT_*') { $queue.Enqueue($p.Type) }
    }
}
$sortedClasses = [ordered]@{}
foreach ($k in ($outClasses.Keys | Sort-Object)) { $sortedClasses[$k] = $outClasses[$k] }

$schema = [ordered]@{
    ModuleName    = 'Microsoft365DSC'
    ModuleVersion = $moduleVersion
    GeneratedOn   = (Get-Date).ToString('yyyy-MM-dd')
    Resources     = $outResources
    Classes       = $sortedClasses
}

$outDir = Split-Path -Path $OutputFile -Parent
if (-not (Test-Path -Path $outDir)) { New-Item -Path $outDir -ItemType Directory | Out-Null }
$schema | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFile -Encoding UTF8
Write-Host "Wrote $($outResources.Count) resources / $($sortedClasses.Count) classes to $OutputFile"
