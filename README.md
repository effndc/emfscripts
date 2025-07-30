# emfscripts

A collection of scripts to accelerate how quickly a clean install of the [Edge Manageability Framework](https://github.com/open-edge-platform/edge-manageability-framework), within [Intel's Open Edge Platform](https://github.com/open-edge-platform), can be ready for use.

Highlevel actions intended to be supported:
- Adding necessary permissions to KeyCloak administrator to perform management tasks in the Orchestrator
- Creating Organizations and associated administrator account with necessary roles
- Creating Projects within Organizations and associated user accounts with necessary roles
- Deleting Organizations

To understand the multi-tenancy concepts please consult the associated documentation: https://docs.openedgeplatform.intel.com/edge-manage-docs/dev/shared/shared_mt_overview.html 

Scripts are released as-is with no implied support by Intel.  Use at your own risk, tests have had limited testing by myself.

This is not intended to replace any user documentation which can be found here https://docs.openedgeplatform.intel.com/edge-manage-docs/ 

# Acknowledgement

I cannot take credit for creation of these scripts alone, many friends and former colleagues had created the initial version of the scripts for use within our internal development and test labs.  I took their work and further enhanced them to make them more flexible and end-user oriented.
