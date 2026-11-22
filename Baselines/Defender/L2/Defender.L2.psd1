@{
    Workload  = 'Defender'
    Level     = 'L2'
    Resources = @(
        # Defender for Office 365 (E5 / P1+) features - CIS profiles these as E5 Level 2.
        @{
            Resource   = 'EXOSafeLinksPolicy'
            Key        = 'CIS'
            Controls   = @('2.1.1')
            Title      = 'Safe Links for Office applications is enabled'
            Properties = @{
                Identity                 = 'CIS Safe Links'
                AdminDisplayName         = 'Managed by M365DSC CIS baseline'
                EnableSafeLinksForEmail  = $true
                EnableSafeLinksForTeams  = $true
                EnableSafeLinksForOffice = $true
                TrackClicks              = $true
                AllowClickThrough        = $false
                ScanUrls                 = $true
                EnableForInternalSenders = $true
                DeliverMessageAfterScan  = $true
                DisableUrlRewrite        = $false
                Ensure                   = 'Present'
            }
        }
        @{
            Resource   = 'EXOSafeLinksRule'
            Key        = 'CIS'
            Controls   = @('2.1.1')
            Title      = 'Safe Links policy is applied to all accepted domains'
            Properties = @{
                Identity          = 'CIS Safe Links'
                SafeLinksPolicy   = 'CIS Safe Links'
                RecipientDomainIs = '{{AcceptedDomains}}'
                Priority          = 0
                Enabled           = $true
                Ensure            = 'Present'
            }
        }
        @{
            Resource   = 'EXOAtpPolicyForO365'
            Key        = 'Default'
            Controls   = @('2.1.5')
            Title      = 'Safe Attachments for SharePoint, OneDrive and Teams is enabled'
            Properties = @{
                IsSingleInstance        = 'Yes'
                EnableATPForSPOTeamsODB = $true
                EnableSafeDocs          = $true
                AllowSafeDocsOpen       = $false
            }
        }
        @{
            Resource   = 'EXOSafeAttachmentPolicy'
            Key        = 'CIS'
            Controls   = @('2.1.4')
            Title      = 'Safe Attachments policy is enabled'
            Properties = @{
                Identity         = 'CIS Safe Attachments'
                AdminDisplayName = 'Managed by M365DSC CIS baseline'
                Enable           = $true
                Action           = 'Block'
                QuarantineTag    = 'AdminOnlyAccessPolicy'
                Ensure           = 'Present'
            }
        }
        @{
            Resource   = 'EXOSafeAttachmentRule'
            Key        = 'CIS'
            Controls   = @('2.1.4')
            Title      = 'Safe Attachments policy is applied to all accepted domains'
            Properties = @{
                Identity             = 'CIS Safe Attachments'
                SafeAttachmentPolicy = 'CIS Safe Attachments'
                RecipientDomainIs    = '{{AcceptedDomains}}'
                Priority             = 0
                Enabled              = $true
                Ensure               = 'Present'
            }
        }

        # 2.1.11 - comprehensive attachment filtering: L2 overlays the L1 malware policy with a
        # much larger blocked extension list.
        @{
            Resource   = 'EXOMalwareFilterPolicy'
            Key        = 'Default'
            Controls   = @('2.1.11')
            Title      = 'Comprehensive attachment filtering is applied'
            Properties = @{
                Identity  = 'Default'
                FileTypes = @(
                    '7z', 'a3x', 'ace', 'ade', 'adp', 'ani', 'apk', 'app', 'appinstaller', 'applescript', 'application',
                    'appref-ms', 'appx', 'appxbundle', 'arj', 'asd', 'asx', 'bas', 'bat', 'bgi', 'bz2', 'cab', 'chm',
                    'cmd', 'com', 'cpl', 'crt', 'cs', 'csh', 'daa', 'dbf', 'dcr', 'deb', 'der', 'desktopthemepackfile',
                    'dex', 'diagcab', 'dif', 'dir', 'dll', 'dmg', 'doc', 'docm', 'dot', 'dotm', 'elf', 'eml', 'exe',
                    'fxp', 'gadget', 'gz', 'hlp', 'hta', 'htc', 'htm', 'html', 'hwpx', 'ics', 'img', 'inf', 'ins',
                    'iqy', 'iso', 'isp', 'jar', 'jnlp', 'js', 'jse', 'kext', 'ksh', 'lha', 'lib', 'library-ms', 'lnk',
                    'lzh', 'macho', 'mam', 'mda', 'mdb', 'mde', 'mdt', 'mdw', 'mdz', 'mht', 'mhtml', 'mof', 'msc',
                    'msi', 'msix', 'msp', 'msrcincident', 'mst', 'ocx', 'odt', 'ops', 'oxps', 'pcd', 'pif', 'plg',
                    'pot', 'potm', 'ppa', 'ppam', 'ppkg', 'pps', 'ppsm', 'ppt', 'pptm', 'prf', 'prg', 'ps1', 'ps11',
                    'ps11xml', 'ps1xml', 'ps2', 'ps2xml', 'psc1', 'psc2', 'pub', 'py', 'pyc', 'pyo', 'pyw', 'pyz',
                    'pyzw', 'rar', 'reg', 'rev', 'rtf', 'scf', 'scpt', 'scr', 'sct', 'searchConnector-ms', 'service',
                    'settingcontent-ms', 'sh', 'shb', 'shs', 'shtm', 'shtml', 'sldm', 'slk', 'so', 'spl', 'stm',
                    'svg', 'swf', 'sys', 'tar', 'theme', 'themepack', 'timer', 'uif', 'url', 'uue', 'vb', 'vbe',
                    'vbs', 'vhd', 'vhdx', 'vxd', 'wbk', 'website', 'wim', 'wiz', 'ws', 'wsc', 'wsf', 'wsh', 'xla',
                    'xlam', 'xlc', 'xll', 'xlm', 'xls', 'xlsb', 'xlsm', 'xlt', 'xltm', 'xlw', 'xml', 'xnk', 'xps',
                    'xsl', 'xz', 'z'
                )
            }
        }
    )
}
