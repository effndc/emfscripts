#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
set -o nounset

# Define variables for rapid re-use
## If not being executed on orchestrator node, define these variables manually for rapid re-use.
CLUSTER_FQDN=
KC_ADMINUSER=
KC_ADMIN_PASSWORD=

## If being executed on orchestrator node, source this script to auto-discover details.
source "$DIR/orch-query.sh" 

# user data -- will prompt for input when not pre-defined 
## Password complexity reuqirements can be viewed https://keycloak.${CLUSTER_FQDN}/admin/master/console/#/master/authentication/policies 
#ORG_ADMIN_PASS=MyInsecurePassw0rd!
# if static org name is desired then define variable below
#org_name=$1

# Flags for Curl
# default, recommended: -s = silent
CURL_FLAGS="-s" 
# for self signed-cert environments add --insecure
#CURL_FLAGS="-s --insecure" 

# !!!!!!!!!!!!!!!!!
# DO NOT EDIT BELOW 
# !!!!!!!!!!!!!!!!!

CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# source KC utils
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/kc-utils.sh"
source "${DIR}/prompt-user.sh"

# Prompt if credentials missing
prompt_orch_credentials
# Prompt for Organization name
prompt_org
# Prompt for Organization Admin password
prompt_org_admin_pass

# authenticate as admin
api_token ${KC_ADMINUSER} ${KC_ADMIN_PASSWORD} ${CLUSTER_FQDN}

# add kc_admin user to org-admin-group 
get_keycloak_user_id ${KC_ADMINUSER} ${CLUSTER_FQDN} ${api_token}
addGroupToKeycloakUser ${api_token} ${user_id} org-admin-group ${CLUSTER_FQDN}

# Refresh token with new groups, create org and org admin user
api_token ${KC_ADMINUSER} ${KC_ADMIN_PASSWORD} ${CLUSTER_FQDN}
createOrg ${org_name} ${CLUSTER_FQDN} ${api_token}
createOrgAdmin  ${org_name} ${CLUSTER_FQDN} ${api_token}

echo -e "${GREEN}Organization ${NC} ${org_name} ${GREEN} and Organization Admin created successfully.${NC}"
echo -e "${GREEN}You may now login at ${NC}http://web-ui.${CLUSTER_FQDN}"
echo -e "${RED}Next step is to create Projects and Project Users.${NC}"
