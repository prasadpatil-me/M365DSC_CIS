@{
    # Organisation-defined hardening beyond CIS L2 (CIS publishes no Level 3).
    # Add resources here using the same schema as the L1/L2 files. Every entry must carry
    # a Controls tag - use your own IDs (e.g. 'MSS-Exchange-001') and record the justification
    # in Title. Applied only when a tenant's BaseLevel is 'L3'.
    Workload  = 'Exchange'
    Level     = 'L3'
    Resources = @()
}
