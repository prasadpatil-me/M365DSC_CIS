@{
    # Single source of truth for the Microsoft365DSC version this repository is tested with.
    # Changing it: install the new version on the build host, run Tools\Update-M365DSCSchema.ps1,
    # run Invoke-Pester .\Tests, read the release notes for [BREAKING CHANGE] entries, then commit
    # this file and Schema\M365DSC.Schema.json together.
    Microsoft365DSC = '2.26.1118.1'
}
