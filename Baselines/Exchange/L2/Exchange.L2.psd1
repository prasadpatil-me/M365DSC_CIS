@{
    Workload  = 'Exchange'
    Level     = 'L2'
    Resources = @(
        # Overlays the L1 EXOOrganizationConfig instance - same Resource + Key, extra property.
        @{
            Resource   = 'EXOOrganizationConfig'
            Key        = 'Default'
            Controls   = @('1.3.6')
            Title      = 'The Customer Lockbox feature is enabled (E5)'
            Properties = @{
                IsSingleInstance       = 'Yes'
                CustomerLockboxEnabled = $true
            }
        }
        @{
            Resource   = 'EXOOwaMailboxPolicy'
            Key        = 'Default'
            Controls   = @('6.5.3')
            Title      = 'Additional storage providers are restricted in Outlook on the web'
            Properties = @{
                Name                                = 'OwaMailboxPolicy-Default'
                AdditionalStorageProvidersAvailable = $false
            }
        }
        @{
            Resource   = 'EXORoleAssignmentPolicy'
            Key        = 'Default'
            Controls   = @('6.3.1')
            Title      = 'Users installing Outlook add-ins is not allowed'
            Properties = @{
                Name      = 'Default Role Assignment Policy'
                IsDefault = $true
                # Default end-user roles WITHOUT 'My Custom Apps', 'My Marketplace Apps' and
                # 'My ReadWriteMailbox Apps'. Compare with Get-RoleAssignmentPolicy before first deploy.
                Roles     = @(
                    'MyBaseOptions'
                    'MyContactInformation'
                    'MyProfileInformation'
                    'MyRetentionPolicies'
                    'MyTextMessaging'
                    'MyVoiceMail'
                    'MyDistributionGroupMembership'
                    'MyDistributionGroups'
                )
                Ensure    = 'Present'
            }
        }
    )
}
