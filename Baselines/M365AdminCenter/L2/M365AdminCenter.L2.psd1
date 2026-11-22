@{
    Workload  = 'M365AdminCenter'
    Level     = 'L2'
    Resources = @(
        @{
            Resource   = 'O365OrgSettings'
            Key        = 'Default'
            Controls   = @('1.3.7')
            Title      = 'Third-party storage services are restricted in Microsoft 365 on the web'
            Properties = @{
                IsSingleInstance                          = 'Yes'
                M365WebEnableUsersToOpenFilesFrom3PStorage = $false
            }
        }
    )
}
