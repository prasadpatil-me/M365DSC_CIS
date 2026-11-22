@{
    # Example tenant - used by the tests and CI. Copy this folder to Tenants\<YourTenant>\ and
    # replace every value. See README "Public repository warning" before committing a real tenant.

    TenantName     = 'Contoso'
    TenantId       = 'contoso.onmicrosoft.com'

    # Certificate-based app-only authentication (recommended for unattended runs).
    # The certificate (with private key) must be in Cert:\LocalMachine\My on the build/agent host.
    Authentication = @{
        ApplicationId         = '00000000-0000-0000-0000-000000000000'
        CertificateThumbprint = '0000000000000000000000000000000000000000'
    }

    # Hardening profile: one base level (L1 | L2 | L3) plus optional add-ons (NG).
    BaseLevel      = 'L2'
    AddOns         = @('NG')

    # Workloads to build. Remove one to leave it unmanaged.
    Workloads      = @('EntraID', 'Exchange', 'Defender', 'Purview', 'SharePoint', 'Teams', 'Intune', 'M365AdminCenter')

    # Values substituted for {{Token}} placeholders in the baseline files. Levels.psd1
    # DefaultTokens (CISAdminRoles, CAPolicyState) can be overridden here too.
    Tokens         = @{
        BreakGlassGroup               = 'SG-EmergencyAccess-Excluded'   # display name; excluded from every CA policy
        ConsentReviewersGroup         = '11111111-1111-1111-1111-111111111111'   # object ID of the admin-consent reviewers group
        BannedPasswords               = @('contoso', 'Contoso2026', 'Password1')
        ExternalInOutlookIdentity     = 'contoso.onmicrosoft.com'   # check with: Get-ExternalInOutlook | Select Identity
        SecurityNotificationMailbox   = 'secops@contoso.com'
        AcceptedDomains               = @('contoso.com', 'contoso.onmicrosoft.com')
        PriorityUsers                 = @('CEO;ceo@contoso.com', 'CFO;cfo@contoso.com')   # 'DisplayName;Address'
        SharingAllowedDomains         = @('fabrikam.com')
        OneDriveSyncDomainGuids       = @('22222222-2222-2222-2222-222222222222')   # on-prem AD domain GUIDs
        TeamsFederationAllowedDomains = @('fabrikam.com')
        IntuneAssignmentGroup         = 'SG-Intune-CIS-Pilot'
        WindowsMinimumOsVersion       = '10.0.22631.0'
        CAPolicyState                 = 'enabledForReportingButNotEnforced'
    }

    # Documented deviations. A resource is skipped only when every control it implements is
    # excepted (or when Resource + Key are given). Expired exceptions fail the build.
    Exceptions     = @(
        @{
            Control    = '8.5.9'
            Reason     = 'Meeting recording required for board meetings (legal hold).'
            ApprovedBy = 'CISO'
            Expires    = '2027-06-30'
        }
    )

    # Tenant-specific property values merged on top of every level (last layer wins).
    Overrides      = @(
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.3'
            Properties = @{ State = 'enabled' }   # legacy auth block already validated in report-only
        }
        @{
            Resource   = 'TeamsMeetingPolicy'
            Key        = 'Global'
            Properties = @{ AllowCloudRecording = $true }   # see exception 8.5.9 above
        }
    )
}
