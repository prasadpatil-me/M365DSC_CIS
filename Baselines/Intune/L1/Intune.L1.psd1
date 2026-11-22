@{
    # Intune. Control 4.1 is from the CIS M365 Foundations Benchmark. Windows device settings
    # are tagged 'W11-*' and correspond to areas of the CIS Microsoft Intune for Windows 11
    # Benchmark - map them to that benchmark's recommendation IDs if you report against it.
    #
    # Policies are assigned to {{IntuneAssignmentGroup}} (a pilot group by default) so the first
    # deployment cannot mark the whole estate non-compliant.
    Workload  = 'Intune'
    Level     = 'L1'
    Resources = @(
        @{
            Resource   = 'IntuneDeviceManagementComplianceSettings'
            Key        = 'Default'
            Controls   = @('4.1')
            Title      = 'Devices without a compliance policy are marked not compliant'
            Properties = @{
                IsSingleInstance                     = 'Yes'
                SecureByDefault                      = $true
                DeviceComplianceCheckinThresholdDays = 30
            }
        }
        @{
            Resource   = 'IntuneDeviceCompliancePolicyWindows10'
            Key        = 'CIS-Windows'
            Controls   = @('W11-Compliance')
            Title      = 'Windows compliance - encryption, secure boot, code integrity, Defender, firewall'
            Properties = @{
                DisplayName              = 'CIS - Windows - Compliance'
                Description              = 'Managed by M365DSC CIS baseline.'
                BitLockerEnabled         = $true
                SecureBootEnabled        = $true
                CodeIntegrityEnabled     = $true
                StorageRequireEncryption = $true
                ActiveFirewallRequired   = $true
                DefenderEnabled          = $true
                RTPEnabled               = $true
                AntivirusRequired        = $true
                AntiSpywareRequired      = $true
                SignatureOutOfDate       = $true
                OsMinimumVersion         = '{{WindowsMinimumOsVersion}}'
                ScheduledActionsForRule  = @(
                    @{
                        CimType    = 'MSFT_MicrosoftGraphDeviceComplianceScheduledActionsForRuleConfiguration'
                        Properties = @{ ActionType = 'block'; GracePeriodHours = 0 }
                    }
                )
                Assignments              = @(
                    @{
                        CimType    = 'MSFT_DeviceManagementConfigurationPolicyAssignments'
                        Properties = @{
                            dataType                                   = '#microsoft.graph.groupAssignmentTarget'
                            groupDisplayName                           = '{{IntuneAssignmentGroup}}'
                            deviceAndAppManagementAssignmentFilterType = 'none'
                        }
                    }
                )
                Ensure                   = 'Present'
            }
        }
        @{
            Resource   = 'IntuneDeviceConfigurationEndpointProtectionPolicyWindows10'
            Key        = 'CIS-Windows'
            Controls   = @('W11-Firewall', 'W11-SmartScreen', 'W11-LocalSecurityOptions', 'W11-UAC')
            Title      = 'Windows endpoint protection - firewall, SmartScreen, local security options, UAC'
            Properties = @{
                DisplayName                                                          = 'CIS - Windows - Endpoint Protection'
                Description                                                          = 'Managed by M365DSC CIS baseline.'
                FirewallProfileDomain                                                = @{ CimType = 'MSFT_MicrosoftGraphwindowsFirewallNetworkProfile'; Properties = @{ FirewallEnabled = 'allowed'; InboundNotificationsBlocked = $true } }
                FirewallProfilePrivate                                               = @{ CimType = 'MSFT_MicrosoftGraphwindowsFirewallNetworkProfile'; Properties = @{ FirewallEnabled = 'allowed'; InboundNotificationsBlocked = $true } }
                FirewallProfilePublic                                                = @{ CimType = 'MSFT_MicrosoftGraphwindowsFirewallNetworkProfile'; Properties = @{ FirewallEnabled = 'allowed'; InboundNotificationsBlocked = $true } }
                SmartScreenEnableInShell                                             = $true
                SmartScreenBlockOverrideForFiles                                     = $true
                LocalSecurityOptionsDoNotStoreLANManagerHashValueOnNextPasswordChange = $true
                LocalSecurityOptionsAllowAnonymousEnumerationOfSAMAccountsAndShares  = $false
                LocalSecurityOptionsAdministratorElevationPromptBehavior             = 'promptForConsentOnTheSecureDesktop'
                Assignments                                                          = @(
                    @{
                        CimType    = 'MSFT_DeviceManagementConfigurationPolicyAssignments'
                        Properties = @{
                            dataType                                   = '#microsoft.graph.groupAssignmentTarget'
                            groupDisplayName                           = '{{IntuneAssignmentGroup}}'
                            deviceAndAppManagementAssignmentFilterType = 'none'
                        }
                    }
                )
                Ensure                                                               = 'Present'
            }
        }
    )
}
