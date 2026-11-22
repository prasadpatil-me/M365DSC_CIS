@{
    Workload  = 'Teams'
    Level     = 'L2'
    Resources = @(
        # Overlays the L1 Global meeting policy.
        @{
            Resource   = 'TeamsMeetingPolicy'
            Key        = 'Global'
            Controls   = @('8.5.1', '8.5.8', '8.5.9')
            Title      = 'Anonymous users cannot join; external meeting chat off; recording off by default'
            Properties = @{
                Identity                           = 'Global'
                AllowAnonymousUsersToJoinMeeting   = $false   # 8.5.1
                AllowExternalNonTrustedMeetingChat = $false   # 8.5.8
                AllowCloudRecording                = $false   # 8.5.9
            }
        }
    )
}
