@{
    Workload  = 'Exchange'
    Level     = 'L1'
    Resources = @(
        @{
            Resource   = 'EXOOrganizationConfig'
            Key        = 'Default'
            Controls   = @('6.1.1', '6.5.1', '6.5.2')
            Title      = 'Mailbox auditing on, modern authentication on, MailTips enabled'
            Properties = @{
                IsSingleInstance                      = 'Yes'
                AuditDisabled                         = $false   # 6.1.1
                OAuth2ClientProfileEnabled            = $true    # 6.5.1
                MailTipsAllTipsEnabled                = $true    # 6.5.2
                MailTipsExternalRecipientsTipsEnabled = $true
                MailTipsGroupMetricsEnabled           = $true
                MailTipsLargeAudienceThreshold        = 25
            }
        }
        @{
            Resource   = 'EXOSharingPolicy'
            Key        = 'Default'
            Controls   = @('1.3.3')
            Title      = 'External sharing of calendars is not available'
            Properties = @{
                Name    = 'Default Sharing Policy'
                Default = $true
                Enabled = $false
                Ensure  = 'Present'
            }
        }
        @{
            Resource   = 'EXORemoteDomain'
            Key        = 'Default'
            Controls   = @('6.2.1')
            Title      = 'All forms of mail forwarding are blocked - remote domain'
            Properties = @{
                Identity           = 'Default'
                DomainName         = '*'
                AutoForwardEnabled = $false
                Ensure             = 'Present'
            }
        }
        @{
            Resource   = 'EXOExternalInOutlook'
            Key        = 'Default'
            Controls   = @('6.2.3')
            Title      = 'Email from external senders is identified'
            Properties = @{
                Identity = '{{ExternalInOutlookIdentity}}'
                Enabled  = $true
            }
        }
        @{
            Resource   = 'EXOTransportConfig'
            Key        = 'Default'
            Controls   = @('6.5.4')
            Title      = 'SMTP AUTH is disabled'
            Properties = @{
                IsSingleInstance                 = 'Yes'
                SmtpClientAuthenticationDisabled = $true
            }
        }
    )
}
