@{
    # Microsoft Defender for Office 365 / Exchange Online Protection (CIS section 2).
    Workload  = 'Defender'
    Level     = 'L1'
    Resources = @(
        @{
            Resource   = 'EXOMalwareFilterPolicy'
            Key        = 'Default'
            Controls   = @('2.1.2', '2.1.3')
            Title      = 'Common attachment types filter enabled; internal users sending malware are reported'
            Properties = @{
                Identity                               = 'Default'
                EnableFileFilter                       = $true
                FileTypeAction                         = 'Reject'
                FileTypes                              = @(
                    'ace', 'ani', 'apk', 'app', 'appx', 'arj', 'bat', 'cab', 'cmd', 'com', 'deb', 'dex',
                    'dll', 'docm', 'elf', 'exe', 'hta', 'img', 'iso', 'jar', 'jnlp', 'kext', 'lha', 'lib',
                    'library', 'lnk', 'lzh', 'macho', 'msc', 'msi', 'msix', 'msp', 'mst', 'pif', 'ppa',
                    'ppam', 'reg', 'rev', 'scf', 'scr', 'sct', 'sys', 'uif', 'vb', 'vbe', 'vbs', 'vxd',
                    'wsc', 'wsf', 'wsh', 'xll', 'xz', 'z'
                )
                ZapEnabled                             = $true
                EnableInternalSenderAdminNotifications = $true
                InternalSenderAdminAddress             = '{{SecurityNotificationMailbox}}'
                Ensure                                 = 'Present'
            }
        }
        @{
            Resource   = 'EXOHostedOutboundSpamFilterPolicy'
            Key        = 'Default'
            Controls   = @('2.1.6', '6.2.1')
            Title      = 'Exchange Online spam policies notify administrators; automatic forwarding is off'
            Properties = @{
                Identity                                  = 'Default'
                BccSuspiciousOutboundMail                 = $true
                BccSuspiciousOutboundAdditionalRecipients = @('{{SecurityNotificationMailbox}}')
                NotifyOutboundSpam                        = $true
                NotifyOutboundSpamRecipients              = @('{{SecurityNotificationMailbox}}')
                AutoForwardingMode                        = 'Off'      # 6.2.1
                Ensure                                    = 'Present'
            }
        }
        @{
            Resource   = 'EXOHostedConnectionFilterPolicy'
            Key        = 'Default'
            Controls   = @('2.1.12', '2.1.13')
            Title      = 'Connection filter IP allow list is empty and safe list is off'
            Properties = @{
                Identity       = 'Default'
                IPAllowList    = @()
                EnableSafeList = $false
                Ensure         = 'Present'
            }
        }
        @{
            Resource   = 'EXOHostedContentFilterPolicy'
            Key        = 'Default'
            Controls   = @('2.1.14')
            Title      = 'Inbound anti-spam policies do not contain allowed domains'
            Properties = @{
                Identity             = 'Default'
                AllowedSenderDomains = @()
                Ensure               = 'Present'
            }
        }
        @{
            Resource   = 'EXOAntiPhishPolicy'
            Key        = 'Default'
            Controls   = @('2.1.7')
            Title      = 'Anti-phishing policy is configured (default policy)'
            Properties = @{
                Identity                            = 'Office365 AntiPhish Default'
                Enabled                             = $true
                PhishThresholdLevel                 = 3
                EnableTargetedUserProtection        = $true
                TargetedUsersToProtect              = '{{PriorityUsers}}'
                TargetedUserProtectionAction        = 'Quarantine'
                EnableOrganizationDomainsProtection = $true
                TargetedDomainProtectionAction      = 'Quarantine'
                EnableMailboxIntelligence           = $true
                EnableMailboxIntelligenceProtection = $true
                MailboxIntelligenceProtectionAction = 'Quarantine'
                EnableSpoofIntelligence             = $true
                AuthenticationFailAction            = 'Quarantine'
                HonorDmarcPolicy                    = $true
                DmarcQuarantineAction               = 'Quarantine'
                DmarcRejectAction                   = 'Reject'
                EnableFirstContactSafetyTips        = $true
                EnableSimilarUsersSafetyTips        = $true
                EnableSimilarDomainsSafetyTips      = $true
                EnableUnusualCharactersSafetyTips   = $true
                EnableUnauthenticatedSender         = $true
                EnableViaTag                        = $true
                Ensure                              = 'Present'
            }
        }
        @{
            Resource   = 'EXOTeamsProtectionPolicy'
            Key        = 'Default'
            Controls   = @('2.4.4')
            Title      = 'Zero-hour auto purge for Microsoft Teams is on'
            Properties = @{
                IsSingleInstance = 'Yes'
                ZapEnabled       = $true
            }
        }
    )
}
