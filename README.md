# M365DSC_CIS

Microsoft365DSC configuration-as-code for the **CIS Microsoft 365 Foundations Benchmark**: one folder per workload, one settings file per hardening level, one tenant file per tenant. The build merges the levels, applies tenant exceptions, validates every property against the exact Microsoft365DSC version you deploy with, and generates the DSC configurations plus a control coverage report.

| | |
|---|---|
| Benchmark | CIS Microsoft 365 Foundations v7.0.0 (+ Windows device settings from the CIS Intune for Windows 11 benchmark) |
| Microsoft365DSC | **2.26.1118.1**, pinned in [`Build/RequiredModules.psd1`](Build/RequiredModules.psd1) |
| Coverage | 84 CIS M365 recommendations + 12 Windows/Intune settings, across 54 resource instances |

---

## Repository layout

```
Baselines/
  Levels.psd1                  Level model, layer order, default tokens
  EntraID/      L1/ L2/ L3/    Authorization policy, CA policies, auth methods, password protection, devices
  Exchange/     L1/ L2/ L3/    Org config, sharing, forwarding, SMTP AUTH, OWA, add-ins
  Defender/     L1/ L2/ L3/    Anti-malware, anti-spam, anti-phish, Safe Links / Attachments, Teams ZAP
  Purview/      L1/ L2/ L3/    Unified audit log, DLP
  SharePoint/   L1/ L2/ L3/    Sharing, guest expiry, legacy auth, idle sign-out, OneDrive sync
  Teams/        L1/ L2/ L3/    Client, federation, meeting and messaging policies
  Intune/       L1/ L2/ L3/ NG/  Compliance settings, Windows compliance + endpoint protection
  M365AdminCenter/ L1/ L2/ L3/ Org settings (apps & services, Forms, third-party storage)
Tenants/
  Contoso/Tenant.psd1          Example tenant: level, tokens, exceptions, overrides
Schema/M365DSC.Schema.json     Property schema extracted from Microsoft365DSC (validation source)
Build/
  CISBaseline.psm1             Build engine (merge, tokens, validation, code generation)
  RequiredModules.psd1         Pinned Microsoft365DSC version
Scripts/
  Initialize-CISBuildHost.ps1  Install pinned module + dependencies, WinRM, cert check, permissions
  Export-CISCurrentState.ps1   Export current tenant state for the managed resources
  Build-CISBaseline.ps1        Build (and compile) a tenant's baseline
  Test-CISDrift.ps1            Read-only drift test against the built MOFs
  Start-CISDeployment.ps1      Apply the baseline (with drift preview and confirmation)
Tools/Update-M365DSCSchema.ps1 Regenerate the schema after a module upgrade
Tests/Baseline.Tests.ps1       Pester - runs in CI on every PR
```

## Hardening levels

| Level | Type | Contains | Use for |
|---|---|---|---|
| **L1** | Base | L1 | Every tenant. Essential settings, low user impact. |
| **L2** | Base | L1 + L2 | High-security tenants. Defence in depth; may reduce functionality. |
| **L3** | Base | L1 + L2 + L3 | **Organisation-defined.** CIS publishes no Level 3, so the L3 folders are empty scaffolds for your own settings beyond L2. Tag them with your own IDs (e.g. `MSS-EXO-001`). |
| **NG** | Add-on | NG | Next Generation Windows Security (from the CIS Intune for Windows benchmark): VBS, Credential Guard, HVCI, DMA protection. Layered on top of any base level. Intune only. |

A tenant picks **one base level plus optional add-ons**, e.g. `BaseLevel = 'L2'; AddOns = @('NG')` builds the `L2+NG` profile, applying layers `L1 > L2 > NG`.

### How layers merge

Each resource instance is identified by `Resource` + `Key`. When the same instance appears in several layers, the later layer **overlays properties** rather than replacing the resource, so L2 only states what it tightens:

```powershell
# Exchange/L1/Exchange.L1.psd1                    # Exchange/L2/Exchange.L2.psd1
@{ Resource = 'EXOOrganizationConfig'             @{ Resource = 'EXOOrganizationConfig'
   Key      = 'Default'                              Key      = 'Default'
   Controls = @('6.1.1','6.5.1','6.5.2')             Controls = @('1.3.6')
   Properties = @{                                   Properties = @{
     IsSingleInstance = 'Yes'                          IsSingleInstance       = 'Yes'
     AuditDisabled    = $false                         CustomerLockboxEnabled = $true
     ... } }                                         } }
```

→ the L2 build emits **one** `EXOOrganizationConfig` block with both sets of properties, tagged `CIS 6.1.1, 6.5.1, 6.5.2, 1.3.6 [L1 > L2]`. This avoids DSC's duplicate-resource-key error that you get when separate per-level configurations set the same singleton.

Complex (CIM) values merge recursively; arrays and scalars are replaced. A resource instance belongs to exactly one workload (enforced by the tests).

## Settings file format

```powershell
@{
    Workload  = 'Teams'          # must match the folder
    Level     = 'L2'             # must match the folder
    Resources = @(
        @{
            Resource   = 'TeamsMeetingPolicy'          # Microsoft365DSC resource name
            Key        = 'Global'                      # logical ID, unique per resource type
            Controls   = @('8.5.1')                    # CIS recommendation IDs (required)
            Title      = 'Anonymous users cannot join a meeting'
            Properties = @{
                Identity                         = 'Global'
                AllowAnonymousUsersToJoinMeeting = $false
                SomeList                         = '{{TokenName}}'      # replaced from the tenant file
                SomeComplexProperty              = @{                   # embedded class
                    CimType    = 'MSFT_ClassName'
                    Properties = @{ Name = 'value' }
                }
            }
        }
    )
}
```

Do **not** put `ApplicationId`, `TenantId` or `CertificateThumbprint` in a baseline file; the build injects them from the tenant file.

## Tenant file

`Tenants/<Name>/Tenant.psd1` (see [`Tenants/Contoso/Tenant.psd1`](Tenants/Contoso/Tenant.psd1)):

| Key | Purpose |
|---|---|
| `TenantId`, `Authentication` | Certificate-based app-only auth. The cert must be in `Cert:\LocalMachine\My` on the agent. |
| `BaseLevel`, `AddOns` | Profile to build. |
| `Workloads` | Workloads to manage; omit one to leave it unmanaged. |
| `Tokens` | Values for `{{Token}}` placeholders: break-glass group, accepted domains, allowed federation domains, Intune pilot group, and so on. An unresolved token fails the build. |
| `Exceptions` | Documented deviations, each with `Reason`, `ApprovedBy`, `Expires` (yyyy-MM-dd). Match by `Control` (the resource is skipped only if **all** its controls are excepted) or by `Resource` + `Key`. **Expired exceptions fail the build.** Exceptions show in `ControlCoverage.csv`. |
| `Overrides` | Tenant-specific property values applied last, e.g. switching one CA policy from report-only to `enabled`. |

**Conditional Access safety:** every CA policy excludes `{{BreakGlassGroup}}` and takes its state from `{{CAPolicyState}}`, which defaults to `enabledForReportingButNotEnforced`. Promote policies one at a time with `Overrides` after reviewing the report-only sign-in logs.

**Intune safety:** policies are assigned to `{{IntuneAssignmentGroup}}` (a pilot group) instead of all devices.

## Workflow

Run on a Windows host in **Windows PowerShell 5.1** (Microsoft365DSC compiles and applies configurations there). Validation and generation alone work on PowerShell 7 on any OS.

```powershell
# 0. One-off: prepare the agent (module, dependencies, WinRM, cert check, permission list)
.\Scripts\Initialize-CISBuildHost.ps1 -Tenant Contoso

# 1. Capture the current state (rollback point; also helps fill in tokens)
.\Scripts\Export-CISCurrentState.ps1 -Tenant Contoso

# 2. Build: merge, validate, generate, compile
.\Scripts\Build-CISBaseline.ps1 -Tenant Contoso
#    -> Output\Contoso\L2+NG\{All, Workloads\<W>, ControlCoverage.csv, BuildManifest.json}

# 3. Drift test (read-only)
.\Scripts\Test-CISDrift.ps1 -BuildPath '.\Output\Contoso\L2+NG'

# 4. Deploy (shows what will change, asks for confirmation; -WhatIf supported)
.\Scripts\Start-CISDeployment.ps1 -BuildPath '.\Output\Contoso\L2+NG' -WhatIf
.\Scripts\Start-CISDeployment.ps1 -BuildPath '.\Output\Contoso\L2+NG'
```

Useful variations:

```powershell
# Generate only (no compile), different level, subset of workloads
.\Scripts\Build-CISBaseline.ps1 -Tenant Contoso -BaseLevel L1 -AddOn @() -Workload Exchange,Teams -SkipCompile

# HTML diff of current state vs. baseline
New-M365DSCDeltaReport -Source <export>.ps1 -Destination '.\Output\Contoso\L2+NG\All\CIS_Contoso_All.ps1' -OutputPath delta.html
```

`Start-CISDeployment` applies the combined `All` MOF by default, so the LCM monitors the whole baseline (`ApplyAndMonitor`). Applying a single `-Workload` MOF replaces the LCM's current configuration with that workload alone; use it for staged roll-outs and finish with a full deployment.

## Schema validation and upgrading Microsoft365DSC

Microsoft365DSC 2.x uses class-based resources and renames properties between monthly releases. For example, 2.26.x moved the `DefaultUserRole*` properties of `AADAuthorizationPolicy` into `DefaultUserRolePermissions` and made `TeamsClientConfiguration` and `TeamsFederationConfiguration` single-instance. Every build therefore validates property names, types, `ValidateSet` values, required keys and embedded classes against `Schema/M365DSC.Schema.json`, before anything reaches a tenant.

To upgrade:

```powershell
Install-Module Microsoft365DSC -RequiredVersion <new> ; Update-M365DSCDependencies
# edit Build\RequiredModules.psd1
.\Tools\Update-M365DSCSchema.ps1          # regenerates the schema from the installed module
Invoke-Pester .\Tests -Output Detailed    # every renamed/removed property fails here
```

Read the release notes for `[BREAKING CHANGE]`, fix any failures, then commit the version pin and the schema together.

## Coverage

Number of controls per settings file:

| Workload | L1 | L2 | L3 | NG |
|---|---|---|---|---|
| Defender | 9 | 4 | (empty) | - |
| EntraID | 24 | 3 | (empty) | - |
| Exchange | 7 | 3 | (empty) | - |
| Intune | 6 | 3 | (empty) | 4 |
| M365AdminCenter | 2 | 1 | (empty) | - |
| Purview | 3 | (empty) | (empty) | - |
| SharePoint | 9 | 4 | (empty) | - |
| Teams | 12 | 3 | (empty) | - |

`ControlCoverage.csv` in each build output lists every control → resource instance → layers → Applied/Excepted.

**Not covered by DSC.** These need your audit script or a manual review:
- Per-object or reporting checks: admin accounts cloud-only/licensed, global admin count, shared-mailbox sign-in, mailbox audit actions per mailbox, MFA registration status.
- DNS: SPF, DMARC. DKIM signing is per-domain; add `EXODkimSigningConfig` entries in an L3 file or the tenant's domains.
- Tenant-specific design: sensitivity labels (3.3.1), PIM role settings, access reviews, Authenticator feature settings, SSPR, app permission policies, Power BI/Fabric (section 9).

## Important caveats

- **Control IDs:** CIS renumbers recommendations between releases. The IDs here target v7.0.0 but were written by hand. Reconcile them against the v7.0.0 PDF (or your CIS workbook) before using `ControlCoverage.csv` as audit evidence. Windows settings are tagged `W11-*` and are not CIS M365 IDs.
- **Licensing:** several L1/L2 items need Entra ID P2 (risk-based CA), Defender for Office 365 (Safe Links/Attachments) or E5 (Customer Lockbox). Except what your licences don't cover.
- **Test first:** run against a test tenant, or review `Test-CISDrift` plus `-WhatIf`, before production. NG (Credential Guard with UEFI lock) cannot be switched off remotely.

## Public repository warning

This repository is public. A real `Tenant.psd1` exposes your tenant ID, app ID, group names, domains and the list of security controls you have excepted, which is useful reconnaissance for an attacker. `.gitignore` therefore commits only the example tenant. Keep real tenant files out of Git, or make the repository private and remove the `Tenants/*` lines from `.gitignore`.
