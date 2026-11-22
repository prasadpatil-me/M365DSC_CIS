@{
    # SharePoint Online and OneDrive (CIS section 7).
    Workload  = 'SharePoint'
    Level     = 'L1'
    Resources = @(
        @{
            Resource   = 'SPOTenantSettings'
            Key        = 'Default'
            Controls   = @('7.2.1', '7.2.2')
            Title      = 'Modern authentication required; SharePoint and OneDrive integration with Entra B2B enabled'
            Properties = @{
                IsSingleInstance           = 'Yes'
                LegacyAuthProtocolsEnabled = $false   # 7.2.1
                EnableAzureADB2BIntegration = $true   # 7.2.2
            }
        }
        @{
            Resource   = 'SPOSharingSettings'
            Key        = 'Default'
            Controls   = @('7.2.3', '7.2.7', '7.2.9', '7.2.11')
            Title      = 'External sharing restricted; link sharing restricted; guest access expires; default link permission View'
            Properties = @{
                IsSingleInstance               = 'Yes'
                SharingCapability              = 'ExternalUserSharingOnly'   # 7.2.3 - new and existing guests, no Anyone links
                DefaultSharingLinkType         = 'Direct'                    # 7.2.7 - Specific people
                ExternalUserExpirationRequired = $true                       # 7.2.9
                ExternalUserExpireInDays       = 30
                DefaultLinkPermission          = 'View'                      # 7.2.11
            }
        }
        @{
            Resource   = 'SPOAccessControlSettings'
            Key        = 'Default'
            Controls   = @('7.2.10', '7.3.1')
            Title      = 'Guests re-authenticate with verification code; infected files cannot be downloaded'
            Properties = @{
                IsSingleInstance             = 'Yes'
                EmailAttestationRequired     = $true   # 7.2.10
                EmailAttestationReAuthDays   = 15
                DisallowInfectedFileDownload = $true   # 7.3.1
            }
        }
        @{
            Resource   = 'SPOBrowserIdleSignout'
            Key        = 'Default'
            Controls   = @('1.3.2')
            Title      = 'Idle session timeout is set to 3 hours or less for unmanaged devices'
            Properties = @{
                IsSingleInstance = 'Yes'
                Enabled          = $true
                WarnAfter        = '02:45:00'
                SignOutAfter     = '03:00:00'
            }
        }
    )
}
