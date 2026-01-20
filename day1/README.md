# Day 1 and Day 2 Operations

These scripts are what I leverage in ny lab during day-to-day operations.

`status_check.sh` checks all of the installed applications for unexpected states.

`dell_node_config_boot.sh` used iDRAC to configure a Dell Xeon server for HTTPSboot based onboarding with the orchestrator. Execute with -h for help, you can define variables for rapid-reuse at top of file.

> NOTE: Script currently is only tested for non-secure boot methods, the option to enable secureboot should work but is untested.

> NOTE: Requires Dell iDRAC tools (racadm) to be installed.
