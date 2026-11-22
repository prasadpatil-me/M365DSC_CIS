@{
    # Benchmark the control IDs in this repository are written against.
    # Control numbering moves between CIS releases - reconcile IDs against the PDF of this
    # version before using the coverage report as audit evidence.
    BenchmarkVersion = 'CIS Microsoft 365 Foundations Benchmark v7.0.0'

    # Order matters: layers are applied left to right, later layers override earlier ones
    # property-by-property for the same Resource + Key.
    Levels           = @(
        @{
            Name        = 'L1'
            Type        = 'Base'
            Layers      = @('L1')
            Description = 'CIS Level 1 - essential hardening with minimal service impact.'
        }
        @{
            Name        = 'L2'
            Type        = 'Base'
            Layers      = @('L1', 'L2')
            Description = 'CIS Level 2 - defence in depth for high-security tenants; may reduce functionality. Includes L1.'
        }
        @{
            Name        = 'L3'
            Type        = 'Base'
            Layers      = @('L1', 'L2', 'L3')
            Custom      = $true
            Description = 'Organisation-defined hardening beyond CIS L2. CIS publishes no Level 3 - put only settings you own and can justify here. Includes L1 + L2.'
        }
        @{
            Name        = 'NG'
            Type        = 'AddOn'
            Layers      = @('NG')
            Description = 'Next Generation Windows Security add-on (CIS Intune for Windows profile): VBS, Credential Guard, HVCI, DMA protection. Layered on top of any base level.'
        }
    )

    # Values every tenant gets unless its Tenant.psd1 overrides the same token name.
    DefaultTokens    = @{
        # Directory roles CIS treats as administrative (CA policies 5.2.2.1, 5.2.2.4, 5.2.2.5).
        CISAdminRoles = @(
            'Global Administrator'
            'Privileged Role Administrator'
            'Privileged Authentication Administrator'
            'Security Administrator'
            'Conditional Access Administrator'
            'Exchange Administrator'
            'SharePoint Administrator'
            'Teams Administrator'
            'User Administrator'
            'Application Administrator'
            'Cloud Application Administrator'
            'Authentication Administrator'
            'Helpdesk Administrator'
            'Password Administrator'
            'Billing Administrator'
            'Intune Administrator'
            'Compliance Administrator'
        )

        # Deploy CA policies in report-only first; flip to 'enabled' per tenant once sign-in logs are clean.
        CAPolicyState = 'enabledForReportingButNotEnforced'
    }
}
