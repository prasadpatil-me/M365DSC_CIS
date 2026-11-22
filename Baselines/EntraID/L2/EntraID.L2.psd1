@{
    Workload  = 'EntraID'
    Level     = 'L2'
    Resources = @(
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.5'
            Controls   = @('5.2.2.5')
            Title      = 'Phishing-resistant MFA strength is required for administrators'
            Properties = @{
                DisplayName            = 'CIS 5.2.2.5 - Phishing-resistant MFA for administrative roles'
                State                  = '{{CAPolicyState}}'
                IncludeRoles           = '{{CISAdminRoles}}'
                ExcludeGroups          = @('{{BreakGlassGroup}}')
                IncludeApplications    = @('All')
                ClientAppTypes         = @('all')
                GrantControlOperator   = 'OR'
                AuthenticationStrength = 'Phishing-resistant MFA'
                Ensure                 = 'Present'
            }
        }
        @{
            Resource   = 'AADConditionalAccessPolicy'
            Key        = 'CIS-5.2.2.8'
            Controls   = @('5.2.2.8')
            Title      = 'Sign-in risk is blocked for medium and high risk (Entra ID P2)'
            Properties = @{
                DisplayName          = 'CIS 5.2.2.8 - Block medium/high sign-in risk'
                State                = '{{CAPolicyState}}'
                IncludeUsers         = @('All')
                ExcludeGroups        = @('{{BreakGlassGroup}}')
                IncludeApplications  = @('All')
                ClientAppTypes       = @('all')
                SignInRiskLevels     = @('high', 'medium')
                GrantControlOperator = 'OR'
                BuiltInControls      = @('block')
                Ensure               = 'Present'
            }
        }

        # L2 tightens the L1 device registration policy: MFA to join/register.
        @{
            Resource   = 'AADDeviceRegistrationPolicy'
            Key        = 'Default'
            Controls   = @('5.1.4.4')
            Title      = 'MFA is required to register or join devices'
            Properties = @{
                IsSingleInstance             = 'Yes'
                MultiFactorAuthConfiguration = 'required'
            }
        }
    )
}
