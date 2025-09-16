# emfscripts

A collection of scripts to accelerate how quickly a clean install of the [Edge Manageability Framework](https://github.com/open-edge-platform/edge-manageability-framework), within [Intel's Open Edge Platform](https://github.com/open-edge-platform), can be ready for use.

> NOTE: Scripts are released as-is with no implied support by Intel.  Use at your own risk, I have done limited testing and some default linting.

This is not intended to replace any user documentation which can be found here <https://docs.openedgeplatform.intel.com/edge-manage-docs/dev/index.html>

Highlevel actions intended to be supported:

* Adding necessary permissions to KeyCloak administrator to perform management tasks in the Orchestrator
* Creating Organizations and associated administrator account with necessary roles
* Creating Projects within Organizations and associated user accounts with necessary roles
* Deleting Organizations

## Usage

Execute the scripts when needed, you may need to `chmod +x *.sh` and then run `./1-create-org.sh` to create an Organization or `./2-create-project.sh` to create Projects within an Organization.

To understand the multi-tenancy concepts please consult the associated documentation: <https://docs.openedgeplatform.intel.com/edge-manage-docs/dev/shared/shared_mt_overview.html>

## General

All of the scripts will prompt the user for inputs, or some inputs can be set to static values to allow for ease of use for repetetive tasks.

### `user-variables.sh`

> NOTE: This file is permitted for the user to modify.

This script/config file allows for setting persistent common values or attempts to query the data from the orchestrator itself via `kubectl` when executed directly on the Orchestrator Node, really focused for on-prem mode.  

CLUSTER_FQDN is to set the CLUSTER_FQDN for the orchestrator deployment, this is consistent with the example scripts within the EMF Deployment Guide and User Guide.
KC_ADMINUSER is the Keycloak administrative user account, the default username is `admin`.
KC_ADMIN_PASSWORD is the password for this administrative account, if this has not been manually changed the script will query it from the kubernetes secrets.

AUTO_COLLECT_VARS when set to true (default) the script will use kubectl to query for the above data, but will only work when executed in on the orchestrator node itself.

> NOTE: The remaining scripts should not be modified other than to fix or improve the functionality.

### `1-create-org.sh`

There is no GUI equivalent of this capability, so this fills a gap in allowing you to quickly create an Organization.  It will create a user account that has the ability to create Projects within the GUI if you so desire, however you will need to manually add users into the corresponding role-based groups as [documented](https://docs.openedgeplatform.intel.com/edge-manage-docs/dev/shared/shared_iam_groups.html).

This script supports creating Organizations within the EMF Orchestrator.  It will prompt the user for necessary details such as an "organization name" and user password, it then creates the organization and organization administrator account ($orgname-admin).  If you create an Organization named "myorg" then the administrator account will be created as "myorg-admin" and sets recommended permission groups within Keycloak.

### `2-create-project.sh`

This action can also be performed within the GUI when logged in as an Organization administrative account, however once the project is created in the GUI you must manually add users to the new project specific role-based groups as [documented](https://docs.openedgeplatform.intel.com/edge-manage-docs/dev/shared/shared_iam_groups.html).

This script supports creating Projects within an existing Organization.  It will query for the list of existing Organization names and prompt the user to copy/paste the Organization to target.  It will then prompt for the org-admin passowrd, a password for the org user, and a "project name".  It will then create the Project and a associated project users $myorg-$myproject-admin and $myorg-$myproject-user, such as "myorg-porject1-admin" and "myorg-project1-user", it adds recommended permission groups within Keycloak.

### `kc-utils.sh` & `prompt-user.sh`

This script is a collection of functions that are re-used within the "create" scripts.

## To Do

Depending on how the product roadmap evolves and features within the `orch-cli` provide more coverage I may add the ability to create custom user accounts and to select which Organization, Project, and "role types" to add them to.

## Acknowledgement

I cannot take credit for creation of these scripts alone, many friends and former colleagues had created the initial version of the scripts for use within our internal development and test labs.  I took their work and further enhanced them to make them more flexible and end-user oriented.

Some assistance was provided by locally host LLM or GitHub Copilot.
