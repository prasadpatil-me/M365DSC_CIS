@{
    # Microsoft Teams (CIS section 8).
    Workload  = 'Teams'
    Level     = 'L1'
    Resources = @(
        @{
            Resource   = 'TeamsClientConfiguration'
            Key        = 'Default'
            Controls   = @('8.1.1', '8.1.2')
            Title      = 'External file sharing only to approved storage; users cannot email a channel'
            Properties = @{
                IsSingleInstance      = 'Yes'
                AllowDropBox          = $false
                AllowBox              = $false
                AllowGoogleDrive      = $false
                AllowShareFile        = $false
                AllowEgnyte           = $false
                AllowEmailIntoChannel = $false   # 8.1.2
            }
        }
        @{
            Resource   = 'TeamsFederationConfiguration'
            Key        = 'Default'
            Controls   = @('8.2.1', '8.2.2', '8.2.3')
            Title      = 'External domains restricted to an allow list; no unmanaged (consumer) Teams communication'
            Properties = @{
                IsSingleInstance          = 'Yes'
                AllowFederatedUsers       = $true
                AllowedDomains            = '{{TeamsFederationAllowedDomains}}'   # 8.2.1 - allow list only
                AllowTeamsConsumer        = $false                                # 8.2.2
                AllowTeamsConsumerInbound = $false                                # 8.2.3
            }
        }
        @{
            Resource   = 'TeamsMeetingPolicy'
            Key        = 'Global'
            Controls   = @('8.5.2', '8.5.3', '8.5.4', '8.5.5', '8.5.6', '8.5.7')
            Title      = 'Meeting lobby, presenter and chat restrictions (Global policy)'
            Properties = @{
                Identity                                   = 'Global'
                AllowAnonymousUsersToStartMeeting          = $false                               # 8.5.2
                AutoAdmittedUsers                          = 'EveryoneInCompanyExcludingGuests'  # 8.5.3
                AllowPSTNUsersToBypassLobby                = $false                               # 8.5.4
                MeetingChatEnabledType                     = 'EnabledExceptAnonymous'            # 8.5.5
                DesignatedPresenterRoleMode                = 'OrganizerOnlyUserOverride'          # 8.5.6
                AllowExternalParticipantGiveRequestControl = $false                               # 8.5.7
                Ensure                                     = 'Present'
            }
        }
        @{
            Resource   = 'TeamsMessagingPolicy'
            Key        = 'Global'
            Controls   = @('8.6.1')
            Title      = 'Users can report security concerns in Teams'
            Properties = @{
                Identity                      = 'Global'
                AllowSecurityEndUserReporting = $true
                Ensure                        = 'Present'
            }
        }
    )
}
