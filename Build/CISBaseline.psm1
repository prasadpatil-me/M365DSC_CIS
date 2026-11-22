<#
    CISBaseline.psm1 - build engine for the M365DSC CIS baseline repository.

    Pipeline:  Levels.psd1 + Baselines/<Workload>/<Layer>/*.psd1
               -> merge layers (L1 -> L2 -> L3, then add-ons such as NG)
               -> apply tenant exceptions and overrides
               -> resolve {{tokens}}
               -> validate every property against Schema/M365DSC.Schema.json
               -> generate DSC configuration scripts (all workloads + one per workload)
               -> (optional) compile MOFs with Microsoft365DSC

    Compatible with Windows PowerShell 5.1 (required by Microsoft365DSC for compiling and
    applying) and PowerShell 7 (generation / validation only, e.g. in CI).
#>

Set-StrictMode -Version 2.0

$script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path
$script:AuthProperties = @('ApplicationId', 'TenantId', 'CertificateThumbprint', 'Credential', 'ApplicationSecret',
    'ManagedIdentity', 'AccessTokens', 'CertificatePath', 'CertificatePassword')
$script:TokenPattern = '\{\{([A-Za-z0-9_]+)\}\}'

#region Loading

function Get-CISRepositoryRoot
{
    [CmdletBinding()]
    param ()
    $script:RepoRoot
}

function Get-CISLevelDefinition
{
    [CmdletBinding()]
    param ()
    Import-PowerShellDataFile -Path (Join-Path -Path $script:RepoRoot -ChildPath 'Baselines/Levels.psd1')
}

function Get-CISWorkload
{
    [CmdletBinding()]
    param ()
    Get-ChildItem -Path (Join-Path -Path $script:RepoRoot -ChildPath 'Baselines') -Directory |
        Sort-Object -Property Name |
        Select-Object -ExpandProperty Name
}

function Get-CISTenantConfig
{
    [CmdletBinding()]
    param ([Parameter(Mandatory)][string] $Tenant)

    $path = Join-Path -Path $script:RepoRoot -ChildPath "Tenants/$Tenant/Tenant.psd1"
    if (-not (Test-Path -Path $path))
    {
        throw "Tenant configuration not found: $path"
    }
    Import-PowerShellDataFile -Path $path
}

function Get-CISSchema
{
    [CmdletBinding()]
    param ([string] $Path = (Join-Path -Path $script:RepoRoot -ChildPath 'Schema/M365DSC.Schema.json'))

    if (-not (Test-Path -Path $Path))
    {
        return $null
    }
    Get-Content -Path $Path -Raw | ConvertFrom-Json
}

function Get-CISSettingsFile
{
    <# Returns the parsed settings files for the given workloads and layers, in layer order. #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)][string[]] $Workload,
        [Parameter(Mandatory)][string[]] $Layer
    )

    foreach ($l in $Layer)
    {
        foreach ($w in $Workload)
        {
            $dir = Join-Path -Path $script:RepoRoot -ChildPath "Baselines/$w/$l"
            if (-not (Test-Path -Path $dir)) { continue }

            foreach ($file in (Get-ChildItem -Path $dir -Filter '*.psd1' -File | Sort-Object -Property Name))
            {
                $data = Import-PowerShellDataFile -Path $file.FullName
                if ($data.Workload -ne $w -or $data.Level -ne $l)
                {
                    throw "$($file.FullName): Workload/Level ('$($data.Workload)'/'$($data.Level)') must match its folder ('$w'/'$l')."
                }
                [pscustomobject]@{
                    Path      = $file.FullName
                    Workload  = $w
                    Layer     = $l
                    Resources = @($data.Resources)
                }
            }
        }
    }
}

#endregion

#region Merging

function Test-CISCimValue
{
    param ($Value)
    ($Value -is [hashtable]) -and $Value.ContainsKey('CimType') -and $Value.ContainsKey('Properties')
}

function Copy-CISValue
{
    param ($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [hashtable])
    {
        $copy = @{}
        foreach ($k in $Value.Keys) { $copy[$k] = Copy-CISValue -Value $Value[$k] }
        return $copy
    }
    if ($Value -is [array])
    {
        return , @($Value | ForEach-Object { Copy-CISValue -Value $_ })
    }
    $Value
}

function Merge-CISProperties
{
    <#
        Overlays $Overlay onto $Base. Scalars and arrays are replaced; single complex (CIM)
        values of the same class are merged recursively so a higher layer can tighten one
        sub-property without restating the rest.
    #>
    param ([hashtable] $Base, [hashtable] $Overlay)

    $result = Copy-CISValue -Value $Base
    foreach ($k in $Overlay.Keys)
    {
        $new = $Overlay[$k]
        $old = $null
        if ($result.ContainsKey($k)) { $old = $result[$k] }

        if ((Test-CISCimValue -Value $old) -and (Test-CISCimValue -Value $new) -and $old.CimType -eq $new.CimType)
        {
            $result[$k] = @{
                CimType    = $new.CimType
                Properties = Merge-CISProperties -Base $old.Properties -Overlay $new.Properties
            }
        }
        else
        {
            $result[$k] = Copy-CISValue -Value $new
        }
    }
    $result
}

function Merge-CISBaseline
{
    <#
        Merges settings files into one ordered set of resource instances keyed by
        "<Resource>|<Key>". Returns an ordered dictionary of pscustomobjects.
    #>
    [CmdletBinding()]
    param ([Parameter(Mandatory)][object[]] $SettingsFile)

    $merged = [ordered]@{}
    foreach ($file in $SettingsFile)
    {
        foreach ($r in $file.Resources)
        {
            foreach ($required in @('Resource', 'Key', 'Controls', 'Properties'))
            {
                if (-not $r.ContainsKey($required))
                {
                    throw "$($file.Path): an entry is missing '$required'."
                }
            }

            $id = '{0}|{1}' -f $r.Resource, $r.Key
            if ($merged.Contains($id))
            {
                $entry = $merged[$id]
                if ($entry.Workload -ne $file.Workload)
                {
                    throw "$id is defined in both '$($entry.Workload)' and '$($file.Workload)'. A resource instance must belong to exactly one workload."
                }
                $entry.Properties = Merge-CISProperties -Base $entry.Properties -Overlay $r.Properties
                $entry.Controls = @($entry.Controls + $r.Controls | Select-Object -Unique)
                $entry.Layers = @($entry.Layers + $file.Layer | Select-Object -Unique)
                if ($r.ContainsKey('Title')) { $entry.Titles = @($entry.Titles + $r.Title) }
            }
            else
            {
                $titles = @()
                if ($r.ContainsKey('Title')) { $titles = @($r.Title) }
                $merged[$id] = [pscustomobject]@{
                    Id         = $id
                    Resource   = $r.Resource
                    Key        = $r.Key
                    Workload   = $file.Workload
                    Controls   = @($r.Controls)
                    Layers     = @($file.Layer)
                    Titles     = $titles
                    Properties = Copy-CISValue -Value $r.Properties
                    Status     = 'Applied'
                    Exception  = $null
                }
            }
        }
    }
    $merged
}

function Resolve-CISLayer
{
    <# Turns a base level + add-ons into the ordered list of layer folders to apply. #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)][string] $BaseLevel,
        [string[]] $AddOn = @()
    )

    $def = Get-CISLevelDefinition
    $base = $def.Levels | Where-Object { $_.Name -eq $BaseLevel -and $_.Type -eq 'Base' }
    if (-not $base)
    {
        $valid = ($def.Levels | Where-Object { $_.Type -eq 'Base' } | ForEach-Object { $_.Name }) -join ', '
        throw "Unknown base level '$BaseLevel'. Valid: $valid"
    }
    $layers = @($base.Layers)
    foreach ($a in $AddOn)
    {
        $add = $def.Levels | Where-Object { $_.Name -eq $a -and $_.Type -eq 'AddOn' }
        if (-not $add)
        {
            $valid = ($def.Levels | Where-Object { $_.Type -eq 'AddOn' } | ForEach-Object { $_.Name }) -join ', '
            throw "Unknown add-on '$a'. Valid: $valid"
        }
        $layers += $add.Layers
    }
    @($layers | Select-Object -Unique)
}

#endregion

#region Tenant exceptions, overrides and tokens

function Format-CISExceptionLabel
{
    param ([hashtable] $Exception)
    if ($Exception.ContainsKey('Resource') -and $Exception.ContainsKey('Key')) { return ('{0}|{1}' -f $Exception['Resource'], $Exception['Key']) }
    if ($Exception.ContainsKey('Control')) { return ('control {0}' -f $Exception['Control']) }
    '(exception without Control or Resource/Key)'
}

function Invoke-CISTenantPolicy
{
    <#
        Applies Exceptions (skip resources, with mandatory reason/approver/expiry) and
        Overrides (tenant-specific property values) to a merged baseline in place.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary] $Baseline,
        [Parameter(Mandatory)][hashtable] $TenantConfig,
        [switch] $AllowExpiredExceptions
    )

    $errors = @()
    $today = (Get-Date).Date

    $exceptions = @()
    if ($TenantConfig.ContainsKey('Exceptions')) { $exceptions = @($TenantConfig.Exceptions) }
    foreach ($ex in $exceptions)
    {
        foreach ($f in @('Reason', 'ApprovedBy', 'Expires'))
        {
            if (-not $ex.ContainsKey($f) -or [string]::IsNullOrWhiteSpace([string]$ex[$f]))
            {
                $errors += "Exception $(($ex.Keys | ForEach-Object { "$_=$($ex[$_])" }) -join '; ') is missing '$f'."
            }
        }
        $expires = [datetime]::MinValue
        if ($ex.ContainsKey('Expires') -and -not [datetime]::TryParseExact([string]$ex['Expires'], 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$expires))
        {
            $errors += "Exception for $(Format-CISExceptionLabel -Exception $ex): Expires '$($ex['Expires'])' must be yyyy-MM-dd."
        }
        elseif ($expires -ne [datetime]::MinValue -and $expires -lt $today -and -not $AllowExpiredExceptions)
        {
            $errors += "Exception for $(Format-CISExceptionLabel -Exception $ex) expired on $($ex['Expires']). Renew or remove it."
        }

        $matched = $false
        foreach ($entry in $Baseline.Values)
        {
            $hit = $false
            if ($ex.ContainsKey('Resource') -and $ex.ContainsKey('Key'))
            {
                $hit = ($entry.Resource -eq $ex['Resource'] -and $entry.Key -eq $ex['Key'])
            }
            elseif ($ex.ContainsKey('Control'))
            {
                # Skip a resource only when EVERY control it implements is excepted.
                $exceptedControls = @($exceptions | Where-Object { $_.ContainsKey('Control') } | ForEach-Object { $_['Control'] })
                $hit = ($entry.Controls -contains $ex['Control']) -and
                    (@($entry.Controls | Where-Object { $exceptedControls -notcontains $_ }).Count -eq 0)
                if (($entry.Controls -contains $ex['Control']) -and -not $hit)
                {
                    Write-Warning "$($entry.Id) implements excepted control $($ex['Control']) but also $((@($entry.Controls | Where-Object { $exceptedControls -notcontains $_ })) -join ', '); it stays applied. Use an Override to relax the specific property."
                    $matched = $true
                }
            }
            if ($hit)
            {
                $entry.Status = 'Excepted'
                $entry.Exception = $ex
                $matched = $true
            }
        }
        if (-not $matched)
        {
            Write-Warning "Exception for $(Format-CISExceptionLabel -Exception $ex) matched nothing in this build."
        }
    }

    $overrides = @()
    if ($TenantConfig.ContainsKey('Overrides')) { $overrides = @($TenantConfig.Overrides) }
    foreach ($ov in $overrides)
    {
        $id = '{0}|{1}' -f $ov.Resource, $ov.Key
        if (-not $Baseline.Contains($id))
        {
            Write-Warning "Override $id does not match a resource in this build (level or workload not selected?)."
            continue
        }
        $Baseline[$id].Properties = Merge-CISProperties -Base $Baseline[$id].Properties -Overlay $ov.Properties
        $Baseline[$id].Layers = @($Baseline[$id].Layers + 'Tenant' | Select-Object -Unique)
    }

    if ($errors) { throw ("Tenant policy errors:`n - " + ($errors -join "`n - ")) }
}

function Resolve-CISTokenValue
{
    param ($Value, [hashtable] $Tokens, [System.Collections.Generic.HashSet[string]] $Missing)

    if ($null -eq $Value) { return $null }
    if ($Value -is [string])
    {
        # A string that is exactly one token takes the token's value as-is (may be an array).
        if ($Value -match "^$($script:TokenPattern)$")
        {
            $name = $Matches[1]
            if ($Tokens.ContainsKey($name)) { return $Tokens[$name] }
            [void]$Missing.Add($name)
            return $Value
        }
        return [regex]::Replace($Value, $script:TokenPattern, {
                param($m)
                $n = $m.Groups[1].Value
                if ($Tokens.ContainsKey($n)) { return [string]$Tokens[$n] }
                [void]$Missing.Add($n)
                return $m.Value
            })
    }
    if ($Value -is [hashtable])
    {
        $out = @{}
        foreach ($k in $Value.Keys) { $out[$k] = Resolve-CISTokenValue -Value $Value[$k] -Tokens $Tokens -Missing $Missing }
        return $out
    }
    if ($Value -is [array])
    {
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($i in $Value)
        {
            $r = Resolve-CISTokenValue -Value $i -Tokens $Tokens -Missing $Missing
            # A token inside an array that resolves to an array is flattened into it.
            if ($r -is [array]) { foreach ($x in $r) { $items.Add($x) } } else { $items.Add($r) }
        }
        return , $items.ToArray()
    }
    $Value
}

function Resolve-CISToken
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary] $Baseline,
        [Parameter(Mandatory)][hashtable] $Tokens
    )

    $missing = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($entry in $Baseline.Values)
    {
        if ($entry.Status -ne 'Applied') { continue }
        $entry.Properties = Resolve-CISTokenValue -Value $entry.Properties -Tokens $Tokens -Missing $missing
    }
    if ($missing.Count -gt 0)
    {
        throw "Unresolved tokens - add them to the tenant's Tokens table: $(@($missing) -join ', ')"
    }
}

#endregion

#region Schema validation

function Test-CISValueAgainstSchema
{
    param ($Value, $PropSchema, [string] $Path, $Schema)

    $errs = @()
    $values = @($Value)
    if (($Value -is [array]) -and -not $PropSchema.IsArray)
    {
        $errs += "$Path is a single value in Microsoft365DSC but an array was supplied."
    }

    foreach ($v in $values)
    {
        if ($null -eq $v) { continue }
        # Unresolved {{Token}} (repository-level validation before tenant values exist).
        if ($v -is [string] -and $v -match "^$($script:TokenPattern)$") { continue }
        $type = [string]$PropSchema.Type
        if ($type -like 'MSFT_*')
        {
            if (-not (Test-CISCimValue -Value $v))
            {
                $errs += "$Path must be a complex value @{ CimType = '$type'; Properties = @{...} }."
                continue
            }
            if ($v.CimType -ne $type)
            {
                $errs += "$Path CimType '$($v.CimType)' should be '$type'."
                continue
            }
            $errs += Test-CISPropertiesAgainstSchema -Properties $v.Properties -TypeSchema $Schema.Classes.$type -Path $Path -Schema $Schema
            continue
        }

        switch ($type)
        {
            'Bool'   { if ($v -isnot [bool]) { $errs += "$Path must be `$true/`$false (got '$v')." } }
            'Int'    { if (-not ($v -is [int] -or $v -is [long])) { $errs += "$Path must be an integer (got '$v')." } }
            'UInt16' { if (-not ($v -is [int] -or $v -is [long])) { $errs += "$Path must be an integer (got '$v')." } }
            'String' { if ($v -isnot [string]) { $errs += "$Path must be a string (got $($v.GetType().Name))." } }
        }

        if ($PropSchema.PSObject.Properties['ValidateSet'] -and $v -is [string])
        {
            $set = @($PropSchema.ValidateSet)
            if (-not ($set | Where-Object { $_ -eq $v }))   # -eq is case-insensitive, like ValidateSet
            {
                $errs += "$Path value '$v' is not one of: $($set -join ', ')."
            }
        }
    }
    $errs
}

function Test-CISPropertiesAgainstSchema
{
    param ([hashtable] $Properties, $TypeSchema, [string] $Path, $Schema)

    $errs = @()
    if (-not $TypeSchema)
    {
        return @("$Path : no schema available for this type.")
    }
    $known = @($TypeSchema.Properties.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($name in $Properties.Keys)
    {
        if ($known -notcontains $name)
        {
            $errs += "$Path.$name is not a property of this resource/class in Microsoft365DSC $($Schema.ModuleVersion)."
            continue
        }
        $errs += Test-CISValueAgainstSchema -Value $Properties[$name] -PropSchema $TypeSchema.Properties.$name -Path "$Path.$name" -Schema $Schema
    }
    foreach ($p in $TypeSchema.Properties.PSObject.Properties)
    {
        $isRequired = ($p.Value.PSObject.Properties['Key'] -and $p.Value.Key) -or ($p.Value.PSObject.Properties['Mandatory'] -and $p.Value.Mandatory)
        if ($isRequired -and -not $Properties.ContainsKey($p.Name))
        {
            $errs += "$Path is missing required property '$($p.Name)'."
        }
    }
    $errs
}

function Test-CISBaselineSchema
{
    <# Validates every applied resource instance. Returns a list of error strings (empty = valid). #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary] $Baseline,
        [Parameter(Mandatory)] $Schema
    )

    $errs = @()
    foreach ($entry in $Baseline.Values)
    {
        $res = $Schema.Resources.($entry.Resource)
        if (-not $res)
        {
            $errs += "$($entry.Id): resource '$($entry.Resource)' is not in the schema (Microsoft365DSC $($Schema.ModuleVersion)). Run Tools\Update-M365DSCSchema.ps1."
            continue
        }
        foreach ($a in $script:AuthProperties)
        {
            if ($entry.Properties.ContainsKey($a))
            {
                $errs += "$($entry.Id): do not set '$a' in a baseline - authentication is injected from the tenant file."
            }
        }
        $props = @{}
        foreach ($k in $entry.Properties.Keys) { if ($script:AuthProperties -notcontains $k) { $props[$k] = $entry.Properties[$k] } }
        $errs += Test-CISPropertiesAgainstSchema -Properties $props -TypeSchema $res -Path $entry.Id -Schema $Schema
    }
    $errs
}

#endregion

#region DSC code generation

function ConvertTo-CISDscLiteral
{
    param ($Value, [int] $Indent)

    $pad = ' ' * $Indent
    if ($null -eq $Value) { return '$null' }
    if ($Value -is [bool]) { if ($Value) { return '$true' } else { return '$false' } }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) { return [string]$Value }
    if ($Value -is [string]) { return "'" + ($Value -replace "'", "''") + "'" }
    if (Test-CISCimValue -Value $Value)
    {
        $lines = @("$($Value.CimType) {")
        $lines += ConvertTo-CISDscPropertyBlock -Properties $Value.Properties -Indent ($Indent + 4)
        $lines += "$pad}"
        return ($lines -join "`r`n")
    }
    if ($Value -is [array])
    {
        $items = @($Value)
        if ($items.Count -eq 0) { return '@()' }
        $allSimple = -not ($items | Where-Object { Test-CISCimValue -Value $_ })
        if ($allSimple)
        {
            $literals = @($items | ForEach-Object { ConvertTo-CISDscLiteral -Value $_ -Indent 0 })
            $inline = '@(' + ($literals -join ', ') + ')'
            if ($inline.Length -le 100) { return $inline }
            $inner = ' ' * ($Indent + 4)
            return "@(`r`n" + (($literals | ForEach-Object { "$inner$_" }) -join "`r`n") + "`r`n$pad)"
        }
        $inner = ' ' * ($Indent + 4)
        $parts = @($items | ForEach-Object { $inner + (ConvertTo-CISDscLiteral -Value $_ -Indent ($Indent + 4)) })
        return "@(`r`n" + ($parts -join "`r`n") + "`r`n$pad)"
    }
    throw "Unsupported value type $($Value.GetType().FullName) in baseline."
}

function ConvertTo-CISDscPropertyBlock
{
    param ([hashtable] $Properties, [int] $Indent, [string[]] $First = @(), [string[]] $Last = @())

    $pad = ' ' * $Indent
    $names = @($First | Where-Object { $Properties.ContainsKey($_) }) +
        @($Properties.Keys | Where-Object { $First -notcontains $_ -and $Last -notcontains $_ } | Sort-Object) +
        @($Last | Where-Object { $Properties.ContainsKey($_) })
    if ($names.Count -eq 0) { return @() }
    $width = ($names | Measure-Object -Property Length -Maximum).Maximum
    foreach ($n in $names)
    {
        $v = $Properties[$n]
        if ($v -is [string] -and $v -match '^\$[A-Za-z][A-Za-z0-9]*$')
        {
            $literal = $v   # variable reference injected by the generator (auth parameters)
        }
        else
        {
            $literal = ConvertTo-CISDscLiteral -Value $v -Indent $Indent
        }
        '{0}{1} = {2}' -f $pad, $n.PadRight($width), $literal
    }
}

function Get-CISInstanceName
{
    param ([string] $Resource, [string] $Key)
    ('{0}_{1}' -f $Resource, $Key) -replace '[^A-Za-z0-9_]', '_'
}

function New-CISConfigurationScript
{
    <# Builds the text of a DSC configuration for a set of resource instances. #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)][string] $ConfigurationName,
        [Parameter(Mandatory)][object[]] $Entries,
        [Parameter(Mandatory)][string] $Header,
        [string] $ModuleVersion,
        $Schema
    )

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine($Header)
    [void]$sb.AppendLine("Configuration $ConfigurationName")
    [void]$sb.AppendLine('{')
    [void]$sb.AppendLine('    param')
    [void]$sb.AppendLine('    (')
    [void]$sb.AppendLine('        [Parameter(Mandatory = $true)] [System.String] $ApplicationId,')
    [void]$sb.AppendLine('        [Parameter(Mandatory = $true)] [System.String] $TenantId,')
    [void]$sb.AppendLine('        [Parameter(Mandatory = $true)] [System.String] $CertificateThumbprint')
    [void]$sb.AppendLine('    )')
    [void]$sb.AppendLine('')
    if ($ModuleVersion)
    {
        [void]$sb.AppendLine("    Import-DscResource -ModuleName 'Microsoft365DSC' -ModuleVersion '$ModuleVersion'")
    }
    else
    {
        [void]$sb.AppendLine("    Import-DscResource -ModuleName 'Microsoft365DSC'")
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('    Node localhost')
    [void]$sb.AppendLine('    {')

    $currentWorkload = $null
    foreach ($e in $Entries)
    {
        if ($e.Workload -ne $currentWorkload)
        {
            $currentWorkload = $e.Workload
            [void]$sb.AppendLine("        #region $currentWorkload")
            [void]$sb.AppendLine('')
        }
        $keyProps = @()
        if ($Schema -and $Schema.Resources.($e.Resource))
        {
            $keyProps = @($Schema.Resources.($e.Resource).Properties.PSObject.Properties |
                    Where-Object { $_.Value.PSObject.Properties['Key'] -and $_.Value.Key } |
                    ForEach-Object { $_.Name })
        }
        $props = Copy-CISValue -Value $e.Properties
        $props['ApplicationId'] = '$ApplicationId'
        $props['TenantId'] = '$TenantId'
        $props['CertificateThumbprint'] = '$CertificateThumbprint'

        [void]$sb.AppendLine("        # CIS $($e.Controls -join ', ') [$($e.Layers -join ' > ')]")
        foreach ($t in $e.Titles) { [void]$sb.AppendLine("        #   $t") }
        [void]$sb.AppendLine("        $($e.Resource) '$(Get-CISInstanceName -Resource $e.Resource -Key $e.Key)'")
        [void]$sb.AppendLine('        {')
        foreach ($line in (ConvertTo-CISDscPropertyBlock -Properties $props -Indent 12 -First $keyProps -Last @('ApplicationId', 'TenantId', 'CertificateThumbprint')))
        {
            [void]$sb.AppendLine($line)
        }
        [void]$sb.AppendLine('        }')
        [void]$sb.AppendLine('')
    }
    if ($currentWorkload) { [void]$sb.AppendLine('        #endregion') }
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('}')
    $sb.ToString()
}

#endregion

#region Build

function Invoke-CISBuild
{
    <#
    .SYNOPSIS
        Builds the CIS baseline for one tenant: merged, validated DSC configurations
        (+ MOFs unless -SkipCompile) and a control coverage report.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)][string] $Tenant,
        [string] $BaseLevel,
        [string[]] $AddOn,
        [string[]] $Workload,
        [string] $OutputPath = (Join-Path -Path $script:RepoRoot -ChildPath 'Output'),
        [switch] $SkipCompile,
        [switch] $SkipSchemaValidation,
        [switch] $AllowExpiredExceptions
    )

    $ErrorActionPreference = 'Stop'
    $tenantConfig = Get-CISTenantConfig -Tenant $Tenant
    $levelDef = Get-CISLevelDefinition

    if (-not $BaseLevel) { $BaseLevel = $tenantConfig.BaseLevel }
    if (-not $PSBoundParameters.ContainsKey('AddOn'))
    {
        $AddOn = @()
        if ($tenantConfig.ContainsKey('AddOns')) { $AddOn = @($tenantConfig.AddOns) }
    }
    $allWorkloads = Get-CISWorkload
    if (-not $Workload)
    {
        $Workload = $allWorkloads
        if ($tenantConfig.ContainsKey('Workloads')) { $Workload = @($tenantConfig.Workloads) }
    }
    foreach ($w in $Workload)
    {
        if ($allWorkloads -notcontains $w) { throw "Unknown workload '$w'. Valid: $($allWorkloads -join ', ')" }
    }

    $layers = Resolve-CISLayer -BaseLevel $BaseLevel -AddOn $AddOn
    $profileName = (@($BaseLevel) + @($AddOn)) -join '+'
    Write-Host "Building '$Tenant' profile $profileName  (layers: $($layers -join ' > '); workloads: $($Workload -join ', '))"

    $files = @(Get-CISSettingsFile -Workload $Workload -Layer $layers)
    $baseline = Merge-CISBaseline -SettingsFile $files
    Invoke-CISTenantPolicy -Baseline $baseline -TenantConfig $tenantConfig -AllowExpiredExceptions:$AllowExpiredExceptions

    $tokens = @{}
    if ($levelDef.ContainsKey('DefaultTokens')) { foreach ($k in $levelDef.DefaultTokens.Keys) { $tokens[$k] = $levelDef.DefaultTokens[$k] } }
    if ($tenantConfig.ContainsKey('Tokens')) { foreach ($k in $tenantConfig.Tokens.Keys) { $tokens[$k] = $tenantConfig.Tokens[$k] } }
    $tokens['TenantId'] = $tenantConfig.TenantId
    Resolve-CISToken -Baseline $baseline -Tokens $tokens

    $applied = [ordered]@{}
    foreach ($k in $baseline.Keys) { if ($baseline[$k].Status -eq 'Applied') { $applied[$k] = $baseline[$k] } }

    $schema = Get-CISSchema
    $moduleVersion = $null
    $requiredModules = Join-Path -Path $script:RepoRoot -ChildPath 'Build/RequiredModules.psd1'
    if (Test-Path -Path $requiredModules)
    {
        $moduleVersion = (Import-PowerShellDataFile -Path $requiredModules).Microsoft365DSC
    }
    if (-not $SkipSchemaValidation)
    {
        if (-not $schema) { throw 'Schema\M365DSC.Schema.json not found. Run Tools\Update-M365DSCSchema.ps1 or pass -SkipSchemaValidation.' }
        if ($moduleVersion -and $schema.ModuleVersion -ne $moduleVersion)
        {
            Write-Warning "Schema was generated from Microsoft365DSC $($schema.ModuleVersion) but Build\RequiredModules.psd1 pins $moduleVersion. Re-run Tools\Update-M365DSCSchema.ps1."
        }
        $errs = @(Test-CISBaselineSchema -Baseline $applied -Schema $schema)
        if ($errs.Count -gt 0)
        {
            throw ("Schema validation failed ($($errs.Count)):`n - " + ($errs -join "`n - "))
        }
        Write-Host "Schema validation passed for $($applied.Count) resource instances (Microsoft365DSC $($schema.ModuleVersion))."
    }

    # ---------------------------------------------------------------- write output
    $root = Join-Path -Path $OutputPath -ChildPath (Join-Path -Path $Tenant -ChildPath $profileName)
    if (Test-Path -Path $root) { Remove-Item -Path $root -Recurse -Force }
    New-Item -Path $root -ItemType Directory -Force | Out-Null

    $safeTenant = $Tenant -replace '[^A-Za-z0-9_]', '_'
    $header = @"
<#
    GENERATED FILE - DO NOT EDIT. Change Baselines/ or Tenants/$Tenant/ and rebuild.
    Benchmark : $($levelDef.BenchmarkVersion)
    Tenant    : $Tenant ($($tenantConfig.TenantId))
    Profile   : $profileName   (layers: $($layers -join ' > '))
    Generated : $((Get-Date).ToString('yyyy-MM-dd HH:mm'))
#>
"@
    $entries = @($applied.Values)
    $configs = @()
    $configs += [pscustomobject]@{
        Name    = "CIS_${safeTenant}_All"
        Folder  = Join-Path -Path $root -ChildPath 'All'
        Entries = $entries
    }
    foreach ($w in $Workload)
    {
        $we = @($entries | Where-Object { $_.Workload -eq $w })
        if ($we.Count -eq 0) { continue }
        $configs += [pscustomobject]@{
            Name    = "CIS_${safeTenant}_$w"
            Folder  = Join-Path -Path $root -ChildPath "Workloads/$w"
            Entries = $we
        }
    }

    foreach ($c in $configs)
    {
        New-Item -Path $c.Folder -ItemType Directory -Force | Out-Null
        $text = New-CISConfigurationScript -ConfigurationName $c.Name -Entries $c.Entries -Header $header -ModuleVersion $moduleVersion -Schema $schema
        $scriptPath = Join-Path -Path $c.Folder -ChildPath "$($c.Name).ps1"
        Set-Content -Path $scriptPath -Value $text -Encoding UTF8
        $c | Add-Member -NotePropertyName Script -NotePropertyValue $scriptPath
    }

    # Coverage report
    $coverage = foreach ($e in $baseline.Values)
    {
        foreach ($ctl in $e.Controls)
        {
            $reason = ''
            if ($e.Exception) { $reason = '{0} (approved by {1}, expires {2})' -f $e.Exception['Reason'], $e.Exception['ApprovedBy'], $e.Exception['Expires'] }
            [pscustomobject]@{
                Control  = $ctl
                Workload = $e.Workload
                Resource = $e.Resource
                Instance = Get-CISInstanceName -Resource $e.Resource -Key $e.Key
                Layers   = $e.Layers -join ' > '
                Status   = $e.Status
                Title    = ($e.Titles -join ' | ')
                Exception = $reason
            }
        }
    }
    $coverage | Sort-Object -Property Workload, Control | Export-Csv -Path (Join-Path -Path $root -ChildPath 'ControlCoverage.csv') -NoTypeInformation -Encoding UTF8

    $manifest = [ordered]@{
        Tenant           = $Tenant
        TenantId         = $tenantConfig.TenantId
        Profile          = $profileName
        Layers           = $layers
        Workloads        = $Workload
        Benchmark        = $levelDef.BenchmarkVersion
        Microsoft365DSC  = $moduleVersion
        SchemaVersion    = $(if ($schema) { $schema.ModuleVersion } else { $null })
        ResourcesApplied = @($baseline.Values | Where-Object { $_.Status -eq 'Applied' }).Count
        ResourcesExcepted = @($baseline.Values | Where-Object { $_.Status -eq 'Excepted' }).Count
        Configurations   = @($configs | ForEach-Object { $_.Name })
        BuiltOn          = (Get-Date).ToString('o')
        Commit           = $(try { (git -C $script:RepoRoot rev-parse --short HEAD 2>$null) } catch { $null })
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path -Path $root -ChildPath 'BuildManifest.json') -Encoding UTF8

    # ---------------------------------------------------------------- compile
    if (-not $SkipCompile)
    {
        if ($PSVersionTable.PSEdition -eq 'Core')
        {
            throw 'Compiling Microsoft365DSC configurations requires Windows PowerShell 5.1. Re-run from powershell.exe, or use -SkipCompile.'
        }
        foreach ($c in $configs)
        {
            Write-Host "Compiling $($c.Name)..."
            . $c.Script
            & $c.Name -ApplicationId $tenantConfig.Authentication.ApplicationId `
                -TenantId $tenantConfig.TenantId `
                -CertificateThumbprint $tenantConfig.Authentication.CertificateThumbprint `
                -OutputPath $c.Folder | Out-Null
        }
    }

    Write-Host ("Done: {0} applied, {1} excepted -> {2}" -f $manifest.ResourcesApplied, $manifest.ResourcesExcepted, $root)
    [pscustomobject]@{
        Path           = $root
        Profile        = $profileName
        Configurations = $configs
        Baseline       = $baseline
    }
}

#endregion

#region Repository validation (used by Tests/ and usable as a pre-commit check)

function Test-CISRepository
{
    <#
    .SYNOPSIS
        Static checks over Baselines/ and Tenants/. Returns issue strings; none = healthy.
    #>
    [CmdletBinding()]
    param ()

    $issues = @()
    $levelDef = Get-CISLevelDefinition
    $levelNames = @($levelDef.Levels | ForEach-Object { $_.Layers } | Select-Object -Unique)
    $schema = Get-CISSchema
    if (-not $schema) { $issues += 'Schema/M365DSC.Schema.json is missing.' }

    $owner = @{}
    foreach ($w in (Get-CISWorkload))
    {
        $wDir = Join-Path -Path $script:RepoRoot -ChildPath "Baselines/$w"
        foreach ($lDir in (Get-ChildItem -Path $wDir -Directory))
        {
            if ($levelNames -notcontains $lDir.Name)
            {
                $issues += "Baselines/$w/$($lDir.Name): folder is not a layer declared in Levels.psd1 ($($levelNames -join ', '))."
            }
        }
        $files = @()
        try { $files = @(Get-CISSettingsFile -Workload $w -Layer $levelNames) }
        catch { $issues += $_.Exception.Message; continue }

        foreach ($f in $files)
        {
            $seen = @{}
            foreach ($r in $f.Resources)
            {
                $label = "$($f.Path | Split-Path -Leaf): $($r.Resource)|$($r.Key)"
                foreach ($req in @('Resource', 'Key', 'Controls', 'Properties', 'Title'))
                {
                    if (-not $r.ContainsKey($req)) { $issues += "$label is missing '$req'." }
                }
                if ($r.ContainsKey('Controls') -and @($r.Controls).Count -eq 0) { $issues += "$label has no Controls." }
                $id = "$($r.Resource)|$($r.Key)"
                if ($seen.ContainsKey($id)) { $issues += "$label is defined twice in the same file." }
                $seen[$id] = $true
                if ($owner.ContainsKey($id) -and $owner[$id] -ne $w)
                {
                    $issues += "$id is defined in workloads '$($owner[$id])' and '$w'. One instance, one workload."
                }
                $owner[$id] = $w
            }
        }
    }

    # Every base level, with and without every add-on, must merge and validate.
    if ($schema)
    {
        $bases = @($levelDef.Levels | Where-Object { $_.Type -eq 'Base' })
        $addOns = @($levelDef.Levels | Where-Object { $_.Type -eq 'AddOn' } | ForEach-Object { $_.Name })
        foreach ($b in $bases)
        {
            foreach ($combo in @(@(), $addOns))
            {
                $name = (@($b.Name) + @($combo)) -join '+'
                try
                {
                    $layers = Resolve-CISLayer -BaseLevel $b.Name -AddOn $combo
                    $merged = Merge-CISBaseline -SettingsFile @(Get-CISSettingsFile -Workload (Get-CISWorkload) -Layer $layers)
                    foreach ($e in @(Test-CISBaselineSchema -Baseline $merged -Schema $schema)) { $issues += "[$name] $e" }
                }
                catch
                {
                    $issues += "[$name] $($_.Exception.Message)"
                }
            }
        }
    }
    $issues
}

#endregion

Export-ModuleMember -Function Test-CISRepository, Get-CISRepositoryRoot, Get-CISLevelDefinition, Get-CISWorkload, Get-CISTenantConfig,
    Get-CISSchema, Get-CISSettingsFile, Merge-CISBaseline, Merge-CISProperties, Resolve-CISLayer, Invoke-CISTenantPolicy,
    Resolve-CISToken, Test-CISBaselineSchema, New-CISConfigurationScript, Invoke-CISBuild
