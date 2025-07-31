#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 @effndc
#
# SPDX-License-Identifier: Apache-2.0

# Please edit the ./user-variables.sh file to modify static or collected user variables.

set -euo pipefail
set -o nounset

CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# source KC utils
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/user-variables.sh" 
source "${DIR}/kc-utils.sh"
source "${DIR}/prompt-user.sh"

# Prompt if credentials missing
prompt_orch_credentials

# Auth for Keycloak/Orch Admin 
#api_token ${KC_ADMINUSER} ${KC_ADMIN_PASSWORD} ${CLUSTER_FQDN}
KC_ADMIN_TOKEN=$(api_token "${KC_ADMINUSER}" "${KC_ADMIN_PASSWORD}" "${CLUSTER_FQDN}")
echo -e "${CYAN} Please get the name of of an Organization to create a Project in:${NC}"

# Usage getOrgs <cluster_fqdn> <jwt_token
getOrgs ${CLUSTER_FQDN} ${KC_ADMIN_TOKEN}

# Prompt for Organization name
prompt_org
# Prompt for Organization password for user accounts
prompt_org_admin_pass
prompt_org_user_pass
# Prompt for Oganization name
prompt_project

# 2 get Project Admin credentials for creating projects within Orch API
# Usage: api_token <user> <pass> <cluster_fqdn> <token_name> [realm] [client_id] [scope]
ORGADMIN_TOKEN=$(api_token "${org_name}-admin" "${ORG_ADMIN_PASS}" "${CLUSTER_FQDN}")

# 3 createProjectInOrg org_name project_name cluster_fqdn jwt_token
# Usage: createProjectInOrg <org_name> <project_name> <cluster_fqdn> <jwt_token>
createProjectInOrg ${org_name} ${project_name} ${CLUSTER_FQDN} ${ORGADMIN_TOKEN} 

# 4 Create Project Admin
# Usage: createProjectAdmin <username> <org_name> <cluster_fqdn> <jwt_token>
createProjectAdmin ${org_name}-${project_name}-admin ${org_name} ${CLUSTER_FQDN} ${KC_ADMIN_TOKEN} 
# 5 Create Project User 
# Usage: createProjectUser <username> <org_name> <project_name> <cluster_fqdn> <jwt_token> [admin_token] [groups]
createProjectUser ${org_name}-${project_name}-user ${org_name} ${CLUSTER_FQDN} ${KC_ADMIN_TOKEN} 


echo -e "${GREEN}Project ${NC} ${project_name} ${GREEN} and Organization users created successfully.${NC}"
echo -e "${GREEN}You may now login at ${NC}http://web-ui.${CLUSTER_FQDN}"
echo -e "${RED}Next step is create your Locations and Regions and then you are ready to onboard nodes and deploy apps" 
