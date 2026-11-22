@{
    # CIS 3.3.1 (sensitivity label policies are published) depends entirely on your label
    # taxonomy, so it is not baselined here. Model SCSensitivityLabel / SCLabelPolicy in an
    # L3 file once the taxonomy is agreed.
    Workload  = 'Purview'
    Level     = 'L2'
    Resources = @()
}
