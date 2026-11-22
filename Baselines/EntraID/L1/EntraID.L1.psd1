@{
    Workload  = 'EntraID'
    Level     = 'L1'
    Resources = @(
        # ---------------------------------------------------------------- Authorization policy
        @{
            Resource   = 'AADAuthorizationPolicy'
            Key        = 'Default'
            Controls   = @('5.1.2.2', '5.1.2.3', '5.1.4.6', '5.1.5.1', '5.1.6.2', '5.1.6.3')
            Title      = 'Users cannot register apps or create tenants, no user consent, guest access restricted'
            Properties = @{
                IsSingleInstance                                  = 'Yes'
                DefaultUserRolePermissions                        = @{
                    CimType    = 'MSFT_DefaultUserRolePermissions'
                    Properties = @{
                        AllowedToCreateApps                      = $false   # 5.1.2.2
                        AllowedToCreateTenants                   = $false   # 5.1.2.3
                        AllowedToReadBitlockerKeysForOwnedDevice = $false   # 5.1.4.6
                    }
                }
                PermissionGrantPolicyIdsAssignedToDefaultUserRole = @()      # 5.1.5.1 - user consent not allowed
                GuestUserRole                                     = 'RestrictedGuest'          # 5.1.6.2
                AllowInvitesFrom                                  = 'AdminsAndGuestInviters'   # 5.1.6.3
            }
        }

        # ---------------------------------------------------------------- Groups
        @{
            Resource   = 'AADGroup'
            Key        = 'DynamicGuests'
            Controls   = @('5.1.3.1')
            Title      = 'A dynamic group for guest users is created'
            Properties = @{
                DisplayName                   = 'CIS - Dynamic - All Guest Users'
                MailNickname                  = 'cis-dynamic-guests'
                Description                   = 'Managed by M365DSC CIS baseline (5.1.3.1). All guest accounts.'
                GroupTypes                    = @('DynamicMembership')
                MembershipRule                = '(user.userType -eq "Guest")'
                MembershipRuleProcessingState = 'On'
                SecurityEnabled               = $true
                MailEnabled                   = $false
                Ensure                        = 'Present'
            }
        }

        # ---------------------------------------------------------------- Admin consent workflow
        @{
            Resource   = 'AADAdminConsentRequestPolicy'
            Key        = 'Default'
            Controls   = @('5.1.5.2')
            Title      = 'The admin consent workflow is enabled'
            Properties = @{
                IsSingleInstance      = 'Yes'
                IsEnabled             = $true
                NotifyReviewers       = $true
                RemindersEnabled      = $true
                RequestDurationInDays = 30
                Reviewers             = @(
                    @{
                        CimType    = 'MSFT_AADAdminConsentRequestPolicyReviewer'
                        Properties = @{
                            ReviewerType = 'Group'
                            ReviewerId   = '{{ConsentReviewersGroup}}'
                        }
                    }
                )
            }
        }

        # ---------------------------------------------------------------- Devices
        @{
            Resource   = 'AADDeviceRegistrationPolicy'
            Key        = 'Default'
            Controls   = @('5.1.4.2', '5.1.4.3', '5.1.4.5')
            Title      = 'Device quota limited, GA not local admin on join, LAPS enabled'
            Properties = @{
                IsSingleInstance              = 'Yes'
                UserDeviceQuota               = 20        # 5.1.4.2
                LocalAdminsEnableGlobalAdmins = $false    # 5.1.4.3
                LocalAdminPasswordIsEnabled   = $true     # 5.1.4.5
            }
        }

        # ---------------------------------------------------------------- Password protection
        @{
            Resource   = 'AADPasswordRuleSettings'
            Key        = 'Default'
            Controls   = @('5.2.3.2', '5.2.3.3')
            Title      = 'Custom banned passwords enforced in cloud and on-premises'
            Properties = @{
                IsSingleInstance                    = 'Yes'
                EnableBannedPasswordCheck           = $true
                BannedPasswordList                  = '{{BannedPasswords}}'
                EnableBannedPasswordCheckOnPremises = $true
                BannedPasswordCheckOnPremisesMode   = 'Enforce'
                LockoutThreshold                    = 10
                LockoutDurationInSeconds            = 60
                Ensure                              = 'Present'
            }
        }

        # ---------------------------------------------------------------- Weak authentication methods
        @{
            Resource   = 'AADAuthenticationMethodPolicySms'
            Key        = 'Sms'
            Controls   = @('5.2.3.5')
            Title      = 'Weak authentication methods are disabled - SMS'
            Properties = @{ Id = 'Sms'; State = 'disabled'; Ensure = 'Present' }
        }
        @{
            Resource   = 'AADAuthenticationMethodPolicyVoice'
            Key        = 'Voice'
            Controls   = @('5.2.3.5')
            Title      = 'Weak authentication methods are disabled - Voice'
            Properties = @{ Id = 'Voice'; State = 'disabled'; Ensure = 'Present' }
        }
        @{
            Resource   = 'AADAuthenticationMethodPolicyEmail'
            Key        = 'Email'
            Controls   = @('5.2.3.5')
            Title      = 'Weak authentication methods are disabled - Email OTP'
            Properties = @{ Id = 'Email'; State = 'disabled'; Ensure = 'Present' }
        }

        # ---------------------------------------------------------------- Conditional Access
        # Every policy excludes the emergency-access group. State comes from {{CAPolicyState}}
        # (report-only by default) so a first deployment can never lock anyone out.
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.1'
            Controls   = @('5.2.2.1')
            Title      = 'MFA is required for administrative roles'
            Properties = @{
                DisplayName          = 'CIS 5.2.2.1 - Require MFA for administrative roles'
                State                = '{{CAPolicyState}}'
                IncludeRoles         = '{{CISAdminRoles}}'
                ExcludeGroups        = @('{{BreakGlassGroup}}')
                IncludeApplications  = @('All')
                ClientAppTypes       = @('all')
                GrantControlOperator = 'OR'
                BuiltInControls      = @('mfa')
                Ensure               = 'Present'
            }
        }
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.2'
            Controls   = @('5.2.2.2')
            Title      = 'MFA is required for all users'
            Properties = @{
                DisplayName          = 'CIS 5.2.2.2 - Require MFA for all users'
                State                = '{{CAPolicyState}}'
                IncludeUsers         = @('All')
                ExcludeGroups        = @('{{BreakGlassGroup}}')
                IncludeApplications  = @('All')
                ClientAppTypes       = @('all')
                GrantControlOperator = 'OR'
                BuiltInControls      = @('mfa')
                Ensure               = 'Present'
            }
        }
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.3'
            Controls   = @('5.2.2.3')
            Title      = 'Conditional Access blocks legacy authentication'
            Properties = @{
                DisplayName          = 'CIS 5.2.2.3 - Block legacy authentication'
                State                = '{{CAPolicyState}}'
                IncludeUsers         = @('All')
                ExcludeGroups        = @('{{BreakGlassGroup}}')
                IncludeApplications  = @('All')
                ClientAppTypes       = @('exchangeActiveSync', 'other')
                GrantControlOperator = 'OR'
                BuiltInControls      = @('block')
                Ensure               = 'Present'
            }
        }
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.4'
            Controls   = @('5.2.2.4')
            Title      = 'Sign-in frequency is enabled and browser sessions are not persistent for administrative users'
            Properties = @{
                DisplayName                = 'CIS 5.2.2.4 - Admin sign-in frequency and non-persistent browser'
                State                      = '{{CAPolicyState}}'
                IncludeRoles               = '{{CISAdminRoles}}'
                ExcludeGroups              = @('{{BreakGlassGroup}}')
                IncludeApplications        = @('All')
                ClientAppTypes             = @('all')
                SignInFrequencyIsEnabled   = $true
                SignInFrequencyInterval    = 'timeBased'
                SignInFrequencyType        = 'Hours'
                SignInFrequencyValue       = 4
                PersistentBrowserIsEnabled = $true
                PersistentBrowserMode      = 'Never'
                Ensure                     = 'Present'
            }
        }
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.6'
            Controls   = @('5.2.2.6')
            Title      = 'Identity Protection user risk policies are enabled (Entra ID P2)'
            Properties = @{
                DisplayName              = 'CIS 5.2.2.6 - High user risk requires MFA and password change'
                State                    = '{{CAPolicyState}}'
                IncludeUsers             = @('All')
                ExcludeGroups            = @('{{BreakGlassGroup}}')
                IncludeApplications      = @('All')
                ClientAppTypes           = @('all')
                UserRiskLevels           = @('high')
                GrantControlOperator     = 'AND'
                BuiltInControls          = @('mfa', 'passwordChange')
                SignInFrequencyIsEnabled = $true
                SignInFrequencyInterval  = 'everyTime'
                SignInFrequencyAuthenticationType = 'primaryAndSecondaryAuthentication'
                Ensure                   = 'Present'
            }
        }
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.7'
            Controls   = @('5.2.2.7')
            Title      = 'Identity Protection sign-in risk policies are enabled (Entra ID P2)'
            Properties = @{
                DisplayName              = 'CIS 5.2.2.7 - Medium/high sign-in risk requires MFA'
                State                    = '{{CAPolicyState}}'
                IncludeUsers             = @('All')
                ExcludeGroups            = @('{{BreakGlassGroup}}')
                IncludeApplications      = @('All')
                ClientAppTypes           = @('all')
                SignInRiskLevels         = @('high', 'medium')
                GrantControlOperator     = 'OR'
                BuiltInControls          = @('mfa')
                SignInFrequencyIsEnabled = $true
                SignInFrequencyInterval  = 'everyTime'
                SignInFrequencyAuthenticationType = 'primaryAndSecondaryAuthentication'
                Ensure                   = 'Present'
            }
        }
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.9'
            Controls   = @('5.2.2.9')
            Title      = 'A managed device is required for authentication'
            Properties = @{
                DisplayName          = 'CIS 5.2.2.9 - Require compliant or hybrid joined device'
                State                = '{{CAPolicyState}}'
                IncludeUsers         = @('All')
                ExcludeGroups        = @('{{BreakGlassGroup}}')
                IncludeApplications  = @('All')
                ClientAppTypes       = @('all')
                GrantControlOperator = 'OR'
                BuiltInControls      = @('compliantDevice', 'domainJoinedDevice')
                Ensure               = 'Present'
            }
        }
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.10'
            Controls   = @('5.2.2.10')
            Title      = 'A managed device is required to register security information'
            Properties = @{
                DisplayName          = 'CIS 5.2.2.10 - Managed device to register security info'
                State                = '{{CAPolicyState}}'
                IncludeUsers         = @('All')
                ExcludeGroups        = @('{{BreakGlassGroup}}')
                IncludeUserActions   = @('urn:user:registersecurityinfo')
                ClientAppTypes       = @('all')
                GrantControlOperator = 'OR'
                BuiltInControls      = @('compliantDevice', 'domainJoinedDevice')
                Ensure               = 'Present'
            }
        }
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.11'
            Controls   = @('5.2.2.11')
            Title      = 'Sign-in frequency for Intune Enrollment is set to Every time'
            Properties = @{
                DisplayName              = 'CIS 5.2.2.11 - Intune enrollment sign-in every time'
                State                    = '{{CAPolicyState}}'
                IncludeUsers             = @('All')
                ExcludeGroups            = @('{{BreakGlassGroup}}')
                IncludeApplications      = @('d4ebce55-015a-49b5-a083-c84d1797ae8c')   # Microsoft Intune Enrollment
                ClientAppTypes           = @('all')
                GrantControlOperator     = 'OR'
                BuiltInControls          = @('mfa')
                SignInFrequencyIsEnabled = $true
                SignInFrequencyInterval  = 'everyTime'
                SignInFrequencyAuthenticationType = 'primaryAndSecondaryAuthentication'
                Ensure                   = 'Present'
            }
        }
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.12'
            Controls   = @('5.2.2.12')
            Title      = 'The device code sign-in flow is blocked'
            Properties = @{
                DisplayName          = 'CIS 5.2.2.12 - Block device code flow'
                State                = '{{CAPolicyState}}'
                IncludeUsers         = @('All')
                ExcludeGroups        = @('{{BreakGlassGroup}}')
                IncludeApplications  = @('All')
                ClientAppTypes       = @('all')
                TransferMethods      = 'deviceCodeFlow'
                GrantControlOperator = 'OR'
                BuiltInControls      = @('block')
                Ensure               = 'Present'
            }
        }
    )
}
