@{
    Workload  = 'Intune'
    Level     = 'L2'
    Resources = @(
        # Overlays the L1 compliance policy: TPM and Defender for Endpoint risk score.
        @{
            Resource   = 'IntuneDeviceCompliancePolicyWindows10'
            Key        = 'CIS-Windows'
            Controls   = @('W11-Compliance-L2')
            Title      = 'Windows compliance - TPM required, device threat level at or under Medium'
            Properties = @{
                DisplayName                                 = 'CIS - Windows - Compliance'
                TpmRequired                                 = $true
                DeviceThreatProtectionEnabled               = $true
                DeviceThreatProtectionRequiredSecurityLevel = 'Medium'
            }
        }
        # Overlays the L1 endpoint protection policy.
        @{
            Resource   = 'IntuneDeviceConfigurationEndpointProtectionPolicyWindows10'
            Key        = 'CIS-Windows'
            Controls   = @('W11-LocalSecurityOptions-L2', 'W11-UAC-L2')
            Title      = 'Windows endpoint protection - NTLMv2/128-bit sessions, deny standard user elevation, clear pagefile'
            Properties = @{
                DisplayName                                                    = 'CIS - Windows - Endpoint Protection'
                LocalSecurityOptionsMinimumSessionSecurityForNtlmSspBasedClients = 'ntlmV2And128BitEncryption'
                LocalSecurityOptionsMinimumSessionSecurityForNtlmSspBasedServers = 'ntlmV2And128BitEncryption'
                LocalSecurityOptionsStandardUserElevationPromptBehavior          = 'automaticallyDenyElevationRequests'
                LocalSecurityOptionsClearVirtualMemoryPageFile                   = $true
            }
        }
    )
}
