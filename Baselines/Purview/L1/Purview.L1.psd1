@{
    Workload  = 'Purview'
    Level     = 'L1'
    Resources = @(
        @{
            Resource   = 'O365AdminAuditLogConfig'
            Key        = 'Default'
            Controls   = @('3.1.1')
            Title      = 'Microsoft 365 audit log search is enabled'
            Properties = @{
                IsSingleInstance                = 'Yes'
                UnifiedAuditLogIngestionEnabled = 'Enabled'
            }
        }

        # 3.2.1 / 3.2.2 - DLP policy covering Exchange, SharePoint, OneDrive and Teams.
        # Starts in TestWithNotifications; set Mode = 'Enable' per tenant via Overrides
        # once policy-match reports have been reviewed.
        @{
            Resource   = 'SCDLPCompliancePolicy'
            Key        = 'CIS-Baseline'
            Controls   = @('3.2.1', '3.2.2')
            Title      = 'DLP policies are enabled, including for Teams'
            Properties = @{
                Name               = 'CIS Baseline - Financial data'
                Comment            = 'Managed by M365DSC CIS baseline.'
                Mode               = 'TestWithNotifications'
                ExchangeLocation   = @('All')
                SharePointLocation = @('All')
                OneDriveLocation   = @('All')
                TeamsLocation      = @('All')
                Ensure             = 'Present'
            }
        }
        @{
            Resource   = 'SCDLPComplianceRule'
            Key        = 'CIS-Baseline-CreditCard'
            Controls   = @('3.2.1', '3.2.2')
            Title      = 'DLP rule - credit card numbers shared externally'
            Properties = @{
                Name                                = 'CIS Baseline - Credit card numbers'
                Policy                              = 'CIS Baseline - Financial data'
                AccessScope                         = 'NotInOrganization'
                BlockAccess                         = $true
                BlockAccessScope                    = 'All'
                NotifyUser                          = @('Owner', 'SiteAdmin', 'LastModifier')
                ReportSeverityLevel                 = 'High'
                ContentContainsSensitiveInformation = @(
                    @{
                        CimType    = 'MSFT_SCDLPContainsSensitiveInformation'
                        Properties = @{
                            SensitiveInformation = @(
                                @{
                                    CimType    = 'MSFT_SCDLPSensitiveInformation'
                                    Properties = @{
                                        name          = 'Credit Card Number'
                                        mincount      = '1'
                                        maxcount      = '-1'
                                        minconfidence = '85'
                                        maxconfidence = '100'
                                    }
                                }
                            )
                        }
                    }
                )
                Ensure                              = 'Present'
            }
        }
    )
}
