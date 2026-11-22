@{
    Workload  = 'SharePoint'
    Level     = 'L2'
    Resources = @(
        # Overlays the L1 SPOSharingSettings instance.
        @{
            Resource   = 'SPOSharingSettings'
            Key        = 'Default'
            Controls   = @('7.2.4', '7.2.5', '7.2.6')
            Title      = 'OneDrive sharing restricted; guests cannot reshare; sharing limited to allowed domains'
            Properties = @{
                IsSingleInstance                  = 'Yes'
                MySiteSharingCapability           = 'ExistingExternalUserSharingOnly'   # 7.2.4
                PreventExternalUsersFromResharing = $true                               # 7.2.5
                SharingDomainRestrictionMode      = 'AllowList'                         # 7.2.6
                SharingAllowedDomainList          = '{{SharingAllowedDomains}}'
            }
        }
        @{
            Resource   = 'ODSettings'
            Key        = 'Default'
            Controls   = @('7.3.2')
            Title      = 'OneDrive sync is restricted for unmanaged devices'
            Properties = @{
                IsSingleInstance        = 'Yes'
                TenantRestrictionEnabled = $true
                DomainGuids             = '{{OneDriveSyncDomainGuids}}'
            }
        }
    )
}
