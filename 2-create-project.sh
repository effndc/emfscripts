#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 @effndc
#
# SPDX-License-Identifier: Apache-2.0

# Please edit the ./user-variables.sh file to modify static or collected user variables.

set -euo pipefail
set -o nounset

# !!!!!!!!!!!!!!!!!
# DO NOT EDIT BELOW 
# !!!!!!!!!!!!!!!!!

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
# Prompt for Organization name
prompt_org
# Prompt for Organization password for user accounts
prompt_org_admin_pass
prompt_org_user_pass
# Prompt for Oganization name
prompt_project

# 1 get keycloak admin token for managing users
api_token ${kc_admin} ${pass} ${CLUSTER_FQDN}

# 2 get Project Admin credentials for creating projects 
jwt_token="$(api_token ${ORG_ADMIN} ${ORG_ADMIN_PASS} ${CLUSTER_FQDN})"
echo ${jwt_token}

# 3 createProjectInOrg org_name project_name cluster_fqdn jwt_token
#createProject ${org_name} ${project_name} ${CLUSTER_FQDN} ${jwt_token} 

# 4 Create Project Admin
# createProjectAdmin username org_name cluster_fqdn jwt_token
#createProjectAdmin ${org_name}-${project_name}-admin ${org_name} ${CLUSTER_FQDN} ${jwt_token} 
# 5 Create Project User 
#createProjectUser 


echo -e "${GREEN}Project ${NC} ${org_name} ${GREEN} and Organization users created successfully.${NC}"
echo -e "${GREEN}You may now login at ${NC}http://web-ui.${CLUSTER_FQDN}"
echo -e "${RED}Next step is create your Locations and Regions and then you are ready to onboard nodes and deploy apps" 
