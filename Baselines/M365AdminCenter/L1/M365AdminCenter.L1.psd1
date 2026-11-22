@{
    # Microsoft 365 admin center org settings (CIS section 1).
    Workload  = 'M365AdminCenter'
    Level     = 'L1'
    Resources = @(
        @{
            Resource   = 'O365OrgSettings'
            Key        = 'Default'
            Controls   = @('1.3.4', '1.3.5')
            Title      = 'User owned apps and services restricted; Forms internal phishing protection on'
            Properties = @{
                IsSingleInstance                            = 'Yes'
                AppsAndServicesIsOfficeStoreEnabled         = $false   # 1.3.4
                AppsAndServicesIsAppAndServicesTrialEnabled = $false   # 1.3.4
                FormsIsInOrgFormsPhishingScanEnabled        = $true    # 1.3.5
            }
        }
    )
}
