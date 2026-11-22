#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
<#
    Offline validation of the baseline - no tenant connection and no Microsoft365DSC install needed.
    Run:  Invoke-Pester -Path .\Tests -Output Detailed
#>

BeforeDiscovery {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $tenants = Get-ChildItem -Path (Join-Path -Path $repoRoot -ChildPath 'Tenants') -Directory |
        Where-Object { Test-Path -Path (Join-Path -Path $_.FullName -ChildPath 'Tenant.psd1') } |
        ForEach-Object { @{ Name = $_.Name } }
    $settingsFiles = Get-ChildItem -Path (Join-Path -Path $repoRoot -ChildPath 'Baselines') -Recurse -Filter '*.psd1' -File |
        Where-Object { $_.Name -ne 'Levels.psd1' } |
        ForEach-Object { @{ Path = $_.FullName; Name = "$($_.Directory.Parent.Name)/$($_.Directory.Name)/$($_.Name)" } }
}

BeforeAll {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $repoRoot -ChildPath 'Build/CISBaseline.psm1') -Force
}

Describe 'Repository structure' {
    It 'Levels.psd1 declares L1, L2, L3 and NG' {
        $names = (Get-CISLevelDefinition).Levels | ForEach-Object { $_.Name }
        $names | Should -Contain 'L1'
        $names | Should -Contain 'L2'
        $names | Should -Contain 'L3'
        $names | Should -Contain 'NG'
    }

    It 'has a schema generated for the pinned Microsoft365DSC version' {
        $schema = Get-CISSchema
        $schema | Should -Not -BeNullOrEmpty
        $pinned = (Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath 'Build/RequiredModules.psd1')).Microsoft365DSC
        $schema.ModuleVersion | Should -Be $pinned
    }

    It 'passes every static repository check (Test-CISRepository)' {
        $issues = @(Test-CISRepository)
        $issues | Should -BeNullOrEmpty -Because ($issues -join "`n")
    }
}

Describe 'Settings file <Name>' -ForEach $settingsFiles {
    BeforeAll {
        $data = Import-PowerShellDataFile -Path $Path
    }

    It 'declares Workload and Level matching its folders' {
        $data.Workload | Should -Be (Split-Path -Path (Split-Path -Path (Split-Path -Path $Path -Parent) -Parent) -Leaf)
        $data.Level | Should -Be (Split-Path -Path (Split-Path -Path $Path -Parent) -Leaf)
    }

    It 'gives every entry Resource, Key, Title, Controls and Properties' {
        foreach ($r in @($data.Resources))
        {
            $r.Keys | Should -Contain 'Resource'
            $r.Keys | Should -Contain 'Key'
            $r.Keys | Should -Contain 'Title'
            $r.Keys | Should -Contain 'Properties'
            @($r.Controls).Count | Should -BeGreaterThan 0 -Because "$($r.Resource)|$($r.Key) must map to at least one control"
        }
    }

    It 'never hard-codes authentication properties' {
        foreach ($r in @($data.Resources))
        {
            foreach ($a in 'ApplicationId', 'TenantId', 'CertificateThumbprint', 'Credential', 'ApplicationSecret')
            {
                $r.Properties.Keys | Should -Not -Contain $a
            }
        }
    }
}

Describe 'Tenant <Name>' -ForEach $tenants {
    BeforeAll {
        $cfg = Get-CISTenantConfig -Tenant $Name
        $out = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "cis-pester-$Name"
    }

    It 'has a valid base level and add-ons' {
        { Resolve-CISLayer -BaseLevel $cfg.BaseLevel -AddOn @($cfg.AddOns) } | Should -Not -Throw
    }

    It 'documents every exception with Reason, ApprovedBy and a future Expires date' {
        foreach ($ex in @($cfg.Exceptions))
        {
            $ex.Reason | Should -Not -BeNullOrEmpty
            $ex.ApprovedBy | Should -Not -BeNullOrEmpty
            [datetime]::ParseExact($ex.Expires, 'yyyy-MM-dd', $null) | Should -BeGreaterThan (Get-Date).Date
        }
    }

    It 'builds, resolves every token and passes schema validation' {
        $result = Invoke-CISBuild -Tenant $Name -OutputPath $out -SkipCompile -WarningAction SilentlyContinue
        $result.Configurations.Count | Should -BeGreaterThan 1
        Test-Path -Path (Join-Path -Path $result.Path -ChildPath 'ControlCoverage.csv') | Should -BeTrue
    }

    It 'generates syntactically valid configuration scripts' {
        Get-ChildItem -Path $out -Recurse -Filter '*.ps1' | ForEach-Object {
            # 'Configuration' needs the DSC keyword cache (Windows only); parse it as a function
            # so the structural check also runs on Linux/macOS agents.
            $src = (Get-Content -Path $_.FullName -Raw) -replace '(?m)^Configuration ', 'function '
            $tokens = $null; $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$tokens, [ref]$errors)
            $errors | Should -BeNullOrEmpty -Because $_.Name
            $src | Should -Not -Match '\{\{[A-Za-z0-9_]+\}\}' -Because "$($_.Name) must not contain unresolved tokens"
        }
    }

    AfterAll {
        if (Test-Path -Path $out) { Remove-Item -Path $out -Recurse -Force }
    }
}

Describe 'Build engine' {
    It 'merges layers property-by-property (L2 tightens L1 without restating it)' {
        $merged = Merge-CISBaseline -SettingsFile @(Get-CISSettingsFile -Workload 'Exchange' -Layer @('L1', 'L2'))
        $org = $merged['EXOOrganizationConfig|Default']
        $org.Properties.AuditDisabled | Should -BeFalse          # from L1
        $org.Properties.CustomerLockboxEnabled | Should -BeTrue  # from L2
        $org.Layers | Should -Be @('L1', 'L2')
    }

    It 'merges complex (CIM) values recursively' {
        $base = @{ P = @{ CimType = 'MSFT_X'; Properties = @{ A = 1; B = 2 } } }
        $over = @{ P = @{ CimType = 'MSFT_X'; Properties = @{ B = 3 } } }
        $r = Merge-CISProperties -Base $base -Overlay $over
        $r.P.Properties.A | Should -Be 1
        $r.P.Properties.B | Should -Be 3
    }

    It 'rejects properties that do not exist in Microsoft365DSC' {
        $bad = [ordered]@{
            'EXOTransportConfig|Default' = [pscustomobject]@{
                Id = 'EXOTransportConfig|Default'; Resource = 'EXOTransportConfig'; Key = 'Default'
                Properties = @{ IsSingleInstance = 'Yes'; NotARealProperty = $true }
            }
        }
        (Test-CISBaselineSchema -Baseline $bad -Schema (Get-CISSchema)) -join ' ' | Should -Match 'NotARealProperty'
    }

    It 'rejects values outside a ValidateSet' {
        $bad = [ordered]@{
            'AADAuthorizationPolicy|Default' = [pscustomobject]@{
                Id = 'AADAuthorizationPolicy|Default'; Resource = 'AADAuthorizationPolicy'; Key = 'Default'
                Properties = @{ IsSingleInstance = 'Yes'; AllowInvitesFrom = 'Anybody' }
            }
        }
        (Test-CISBaselineSchema -Baseline $bad -Schema (Get-CISSchema)) -join ' ' | Should -Match 'AllowInvitesFrom'
    }
}
