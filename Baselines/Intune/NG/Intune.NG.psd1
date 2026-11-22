@{
    # Next Generation Windows Security add-on. Requires hardware that supports VBS/HVCI
    # (TPM 2.0, UEFI Secure Boot, IOMMU). Pilot on representative models first - Credential
    # Guard with UEFI lock cannot be turned off remotely.
    Workload  = 'Intune'
    Level     = 'NG'
    Resources = @(
        @{
            Resource   = 'IntuneDeviceConfigurationEndpointProtectionPolicyWindows10'
            Key        = 'CIS-Windows'
            Controls   = @('W11-NG-VBS', 'W11-NG-CredentialGuard', 'W11-NG-SystemGuard')
            Title      = 'VBS with Secure Boot and DMA protection, Credential Guard with UEFI lock, System Guard'
            Properties = @{
                DisplayName                                            = 'CIS - Windows - Endpoint Protection'
                DeviceGuardEnableVirtualizationBasedSecurity           = $true
                DeviceGuardSecureBootWithDMA                           = 'withDMA'
                DeviceGuardLocalSystemAuthorityCredentialGuardSettings = 'enableWithUEFILock'
                DeviceGuardLaunchSystemGuard                           = 'enabled'
            }
        }
        @{
            Resource   = 'IntuneDeviceCompliancePolicyWindows10'
            Key        = 'CIS-Windows'
            Controls   = @('W11-NG-Compliance')
            Title      = 'Compliance requires VBS, memory integrity (HVCI), kernel DMA and firmware protection'
            Properties = @{
                DisplayName                        = 'CIS - Windows - Compliance'
                VirtualizationBasedSecurityEnabled = $true
                MemoryIntegrityEnabled             = $true
                KernelDmaProtectionEnabled         = $true
                FirmwareProtectionEnabled          = $true
            }
        }
    )
}
