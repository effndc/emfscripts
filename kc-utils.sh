#!/bin/bash

# SPDX-FileCopyrightText: 2025 @effndc
#
# SPDX-License-Identifier: Apache-2.0

# Note: Many functions exist that are not used or tested at this time

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

: '
required inputs to all fucntions are username, password, cluster_fqdn
some functions require additional input of project_name 

Primary actions:
createOrg: create an organization within Edge Platform Orchestrators
createProjectInOrg: create project in Edge Platform Orchestrators
createProjectAdmin: create Keycloak User and assign permission groups

'
# retrieve API token 
# Output: api_token
# AI Improved: api_token function with realm, client_id, and scope as parameters
# Usage: api_token <user> <pass> <cluster_fqdn> [realm] [client_id] [scope]
function api_token() {
  local user="$1"
  local pass="$2"
  local cluster_fqdn="$3"
  local realm="${4:-master}"                # Default to 'master' if not provided
  local client_id="${5:-system-client}"     # Default to 'system-client' if not provided
  local scope="${6:-openid}"                # Default to 'openid' if not provided

  api_token=$(curl "${CURL_FLAGS}" -s -X POST \
    "https://keycloak.${cluster_fqdn}/realms/${realm}/protocol/openid-connect/token" \
    -d "username=${user}" \
    -d "password=${pass}" \
    -d "grant_type=password" \
    -d "client_id=${client_id}" \
    -d "scope=${scope}" | jq -r '.access_token')

  if [[ -z "$api_token" || "$api_token" == "null" ]]; then
    echo -e "${RED}Cannot retrieve API Token from $cluster_fqdn for user ${user} in realm ${realm} ${NC}" >&2
    exit 1
  fi
  #print token for re-use in manual API calls for testing 
  #echo "Authentication token retrieved for ${user} in realm ${realm}"
  #echo "$api_token"
}

# Create Org in Orchestrator
# Usage: createOrg <org_name> <cluster_fqdn> <jwt_token>
function createOrg() {
  local org_name=$1
  local cluster_fqdn=$2
  local jwt_token=$3

  echo -e "${CYAN}Creating Organization ${org_name} ${NC}"

  tmp="$(mktemp)"
  http_code=$(curl "${CURL_FLAGS}" -o "$tmp" -w "%{http_code}" -X PUT "https://api.${cluster_fqdn}/v1/orgs/${org_name}" -H "accept: application"  -H "Authorization: Bearer ${jwt_token}" -H "Content-Type: application/json" -d "{\"description\":\"${org_name}\"}")

  # if http_code is not 200, print the error message
  if [ "$http_code" -ne 200 ]; then
    echo -e "${RED}Cannot create Organization ${org_name} ${NC}" >&2
    cat "$tmp"
    rm "$tmp"
    exit 1
  fi

  rm "$tmp"

  while [ "$(curl "${CURL_FLAGS}" --location "https://api.${cluster_fqdn}/v1/orgs/${org_name}" -H "accept: application/json" -H "Content-Type: application" -H "Authorization: Bearer ${jwt_token}" | jq -r .status.orgStatus.statusIndicator)" != "STATUS_INDICATION_IDLE" ]; do
    echo "Waiting for ${org_name} to be provisioned..."
    sleep 5
  done

  org_uuid=$(curl "${CURL_FLAGS}" --location "https://api.${cluster_fqdn}/v1/orgs/${org_name}" -H "accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${jwt_token}" | jq -r .status.orgStatus.uID)
  if [ "$org_uuid" == "null" ]; then
    echo -e "${RED}Cannot retrieve Org UID for ${org_name} ${NC}" >&2
    exit 1
  fi

  echo -e "${CYAN}Organization ${org_name} has been successfully created -- Organization UUID is ${org_uuid} ${NC}"
}

# createOrgAdmin org_name cluster_fqdn jwt_token
function createOrgAdmin {  
  local org_name=$1
  local cluster_fqdn=$2
  local jwt_token=$3
  #  creating admin user in org
  org_admin_user="${org_name}-admin"
  if [ "$org_uuid" == "null" ]; then
    echo -e "${RED}Organization UUID not known or does not exist ${NC}" >&2
    exit 1
  fi
  echo -e "${CYAN}Creating user ${org_admin_user} within ${org_name}, organization UUID is ${org_uuid} ${NC}" 
  org_admin_uid=$(createKeycloakUser "${jwt_token}" "${org_admin_user}" "${ORG_ADMIN_PASS}" "${cluster_fqdn}")
  if [ "$org_admin_uid" == "null" ]; then
    echo -e "${RED}Failed to create admin user ${org_admin_user} in Keycloak ${NC}" >&2
    exit 1
  fi
  org_project_manager_group_uid=$(curl "${CURL_FLAGS}" -X GET "https://keycloak.${cluster_fqdn}/admin/realms/master/groups?search=${org_uuid}_Project-Manager-Group" -H "Authorization: Bearer ${jwt_token}" | jq -r '.[0].id')
  if [ "$org_project_manager_group_uid" == "null" ]; then
      echo -e "${RED}Project Manager group not found in Keycloak for org ${org_name} (${org_uuid}, Organization creation may have failed ${NC}" >&2
      exit 1
  fi
  #echo -e "Creating Organization admin user: ${org_admin_user}"
  #curl ${CURL_FLAGS} -X PUT "https://keycloak.${cluster_fqdn}/admin/realms/master/users/${org_admin_uid}/groups/${org_project_manager_group_uid}" \
  #     -H "Authorization: Bearer ${jwt_token}" \
  #     -H "Content-Type: application/json" \
  #     -d '{}'
  project_user_groups=("Project-Manager-Group")
  for group in "${project_user_groups[@]}"; do
    echo -e "Adding ${org_admin_user} to Organization groups: ${project_user_groups}"
    # addGroupToKeycloakUser token user_id group_name cluster_fqdn
    addGroupToKeycloakUser "${jwt_token}" "${org_admin_uid}" "${org_uuid}_${group}" "${cluster_fqdn}"
  done
  echo -e "${CYAN}Admin user ${org_admin_user} has been successfully created in ${org_name} ${NC}"
}

# Usage: createProjectInOrg <org_name> <project_name> <cluster_fqdn> <jwt_token>
function createProjectInOrg() {
    local org_name=$1
    local project_name=$2
    local cluster_fqdn=$3
    local jwt_token=$4
    curl "${CURL_FLAGS}" -X PUT "https://api.${cluster_fqdn}/v1/projects/${project_name}" -H "accept: application/json" -H "Authorization: Bearer ${jwt_token}" -H "Content-Type: application/json" -d "{\"description\":\"${project_name}\"}"

    while [ "$(curl "${CURL_FLAGS}" --location "https://api.${cluster_fqdn}/v1/projects/${project_name}" -H "accept: application/json" -H "Content-Type: application" -H "Authorization: Bearer ${jwt_token}" | jq -r .status.projectStatus.statusIndicator)" != "STATUS_INDICATION_IDLE" ]; do
      echo "Waiting for ${project_name} to be provisioned..."
      sleep 5
    done
    echo -e "${CYAN}Project ${project_name} has been successfully created in ${org_name} ${NC}"
}

# Usage: createProjectAdmin <username> <org_name> <cluster_fqdn> <jwt_token>
function createProjectAdmin() {
  local username=$1
  local org_name=$2
  local cluster_fqdn=$3
  local jwt_token=$4 # Admin token with permissions to create users in keycloak and read orgs

  echo -e "${CYAN}Creating Project Admin ${username} in org ${org_name} ${NC}"
  org_uuid=$(curl "${CURL_FLAGS}" --location "https://api.${cluster_fqdn}/v1/orgs/${org_name}" -H "accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${jwt_token}" | jq -r .status.orgStatus.uID)
  if [ "$org_uuid" == "null" ]; then
    echo -e "${RED}Cannot retrieve Org UID for ${org_name} ${NC}" >&2
    exit 1
  fi
  
  if [ -z "${ORG_ADMIN_PASS=+xxx}" ]; then
    echo -e "${CYAN} Org Admin account will be created as ${org_name}-admin"
    echo -e "${GREEN}"
    read -p '??? Provide requested user password :  ' ORG_ADMIN_PASS
    echo -e "${NC}"
  else
    echo -e "${CYAN}Organization admin will be created as ${org_name}-admin with password ${ORG_ADMIN_PASS} ${NC}" 
  fi

  proj_admin_user_id=$(createKeycloakUser "${jwt_token}" "${username}" "${ORG_ADMIN_PASS}" "${cluster_fqdn}")
  echo "User ${username} ID: ${proj_admin_user_id}"
  project_user_groups=("${org_uuid}_Project-Manager-Group")
  for group in "${project_user_groups[@]}"; do
    addGroupToKeycloakUser "${jwt_token}" "${proj_admin_user_id}" "${group}" "${cluster_fqdn}"
  done
  echo -e "${CYAN}Project Admin user ${username} has been successfully created for orchestrator Organization ${org_name} ${NC}"
  echo -e "${CYAN}You may now login to https://web-ui.${cluster_fqdn} with this user and password: ${ORG_ADMIN_PASS} ${NC}"
}

# Create Project User 
# Usage: createProjectUser <username> <org_name> <project_name> <cluster_fqdn> <jwt_token> [admin_token] [groups]
function createProjectUser() {
  local username=$1
  local org_name=$2
  local project_name=$3
  local cluster_fqdn=$4
  local jwt_token=$5 # User token with permission to read projects in the org
  local admin_token=$6 # Admin token with permissions to create users in keycloak
  #local groups=$7

  #if [[ -z "$groups" ]]; then
  #    groups=("Edge-Manager-Group" "Edge-Onboarding-Group" "Edge-Operator-Group" "Host-Manager-Group")
  #fi
  groups=("Edge-Manager-Group" "Edge-Onboarding-Group" "Edge-Operator-Group" "Host-Manager-Group")
  echo -e "${CYAN}Creating Project User ${username} in project ${project_name} and org ${org_name} ${NC}"
  proj_uuid=$(curl "${CURL_FLAGS}" --location "https://api.${cluster_fqdn}/v1/projects/${project_name}" -H "accept: application/json" -H "Content-Type: application" -H "Authorization: Bearer ${jwt_token}" | jq -r .status.projectStatus.uID)
  if [ "$proj_uuid" == "null" ]; then
    echo -e "${RED}Cannot retrieve Project UID for ${project_name} in ${org_name} ${NC}" >&2
    exit 1
  fi
  
  if [ -z "${ORG_USER_PASS+xxx}" ]; then
    echo -e "${GREEN}"
    read -p '??? Provide requested Org User password :  ' org_user_pass
    echo -e "${NC}"
  else
    echo -e "${CYAN}Organization admin will be created as ${org_name} with password ${ORG_USER_PASS} ${NC}" 
  fi

  user_id=$(createKeycloakUser "${admin_token}" "${username}" "${ORG_USER_PASS}" "${cluster_fqdn}")
  for group in "${groups[@]}"; do
    addGroupToKeycloakUser "${admin_token}" "${user_id}" "${proj_uuid}_${group}" "${cluster_fqdn}"
  done
  echo -e "${CYAN}Project User ${username} has been successfully created in ${project_name} ${NC}"
}

# Create KeyCloakUser
# Usage: createKeycloakUser <token> <username> <password> <cluster_fqdn>
function createKeycloakUser() {
  local token=$1
  local username=$2
  local password=$3
  local cluster_fqdn=$4
  curl "${CURL_FLAGS}" -X POST "https://keycloak.${cluster_fqdn}/admin/realms/master/users" \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer ${token}" \
       -d '{
             "username": "'"${username}"'",
             "email":"'"${username}@${cluster_fqdn}"'",
             "enabled": true,
             "emailVerified": true,
             "credentials": [{
                 "type": "password",
                 "value": "'"${password}"'",
                 "temporary": false
             }]
           }' > /dev/null
  curl "${CURL_FLAGS}" -X GET "https://keycloak.${cluster_fqdn}/admin/realms/master/users?username=${username}" -H "Authorization: Bearer ${token}" | jq -r '.[0].id'
}

# Add User to Groups in KeyCloak 
# Usage: addGroupToKeycloakUser <token> <user_id> <group_name> <cluster_fqdn>
function OFFaddGroupToKeycloakUser() {
  local token=$1
  local user_id=$2
  local group_name=$3
  local cluster_fqdn=$4
  echo -e "${CYAN}Adding user to group ${group_name} ${NC} "
  group_id=$(curl "${CURL_FLAGS}" -X GET "https://keycloak.${cluster_fqdn}/admin/realms/master/groups?search=${group_name}" -H "Authorization: Bearer ${token}" | jq -r '.[0].id')
  #TODO
  # if group_id is null, exit with error
  if [ "$group_id" == "null" ]; then
    echo -e "${RED}Failed to find ${group_name} group in Keycloak ${NC}" >&2
    exit 1
  fi
  curl "${CURL_FLAGS}" -X PUT "https://keycloak.${cluster_fqdn}/admin/realms/master/users/${user_id}/groups/${group_id}" \
       -H "Authorization: Bearer ${token}" \
       -H "Content-Type: application/json" \
       -d '{}'
}

# Usage: addGroupToKeycloakUser <token> <user_id> <group_name> <cluster_fqdn>
function addGroupToKeycloakUser() {
  local token="$1"
  local user_id="$2"
  local group_name="$3"
  local cluster_fqdn="$4"
  echo -e "${CYAN}Adding user to group ${group_name} ${NC}"
  group_id=$(curl "${CURL_FLAGS}" -X GET "https://keycloak.${cluster_fqdn}/admin/realms/master/groups?search=${group_name}" \
              -H "Authorization: Bearer ${token}" | jq -r '.[0].id')

  if [ -z "$group_id" ] || [ "$group_id" == "null" ]; then
    echo -e "${RED}Failed to find ${group_name} group in Keycloak ${NC}" >&2
    exit 1
  fi

  curl "${CURL_FLAGS}" -X PUT "https://keycloak.${cluster_fqdn}/admin/realms/master/users/${user_id}/groups/${group_id}" \
       -H "Authorization: Bearer ${token}" \
       -H "Content-Type: application/json" \
       -d '{}'
}


# Get all orgs from Orchestrator
# Usage getOrgs <cluster_fqdn> <jwt_token
function getOrgs() {
  local cluster_fqdn=$1
  local jwt_token=$2
  orgs_list=$(curl "${CURL_FLAGS}" -X GET "https://api.${cluster_fqdn}/v1/orgs" -H "accept: application/json" -H "Authorization: Bearer ${jwt_token}" -H "Content-Type: application/json" |  jq '.[].name' )
  echo "${orgs_list}"
}

# Usage: deleteOrg <org_name> <cluster_fqdn> <jwt_token>
function deleteOrg() {
  local org_name=$1
  local cluster_fqdn=$2
  local jwt_token=$3

  echo -e "${CYAN}Deleting Organization ${org_name} ${NC}"
  response=$(curl "${CURL_FLAGS}" -o /dev/null -w "%{http_code}" -X DELETE "https://api.${cluster_fqdn}/v1/orgs/${org_name}" \
        -H "Authorization: Bearer ${jwt_token}")

    if [ "$response" -eq 200 ]; then
        echo "Organization ${org_name} deleted successfully."
    else
        echo "Failed to delete Organization ${org_name}. HTTP response code: $response"
        exit 1
    fi
}

# Usage: getProjects <cluster_fqdn> <jwt_token>
# Returns: list of projects with their names and UIDs
# Org selection is based on the JWT token provided, so the user must have permissions to delete the project
function getProjects () {
  local cluster_fqdn=$1
  local jwt_token=$2
  echo -e "${CYAN}Retrieving all projects ${NC}"
  echo "| Project Name | Project UID |"
  curl "${CURL_FLAGS}" -X GET "https://api.${cluster_fqdn}/v1/projects" -H "Authorization: Bearer ${jwt_token}" | jq -r '.[] | select(.name and .status.projectStatus.uID) | "| \(.name) | \(.status.projectStatus.uID)"'
}

# Usage: deleteProject <project_name> <cluster_fqdn> <jwt_token>
# Org selection is based on the JWT token provided, so the user must have permissions to delete the project
function deleteProject() {
  local project_name=$1
  local cluster_fqdn=$2
  local jwt_token=$3
  echo -e "${CYAN}Deleting Project ${project_name} ${NC}"
  response=$(curl "${CURL_FLAGS}" -o /dev/null -w "%{http_code}" -X DELETE "https://api.${cluster_fqdn}/v1/projects/${project_name}" \
        -H "Authorization: Bearer ${jwt_token}")
    if [ "$response" -eq 200 ]; then
        echo "Project ${project_name} deleted successfully."
    else
        echo "Failed to delete Project ${project_name}. HTTP response code: $response"
        exit 1
    fi
}

# Usage: get_keycloak_user_id <username> <cluster_fqdn> <jwt_token>
# Returns: user_id
function get_keycloak_user_id() {
    local username="$1"
    local cluster_fqdn="$2"
    local jwt_token="$3"
    echo -e "Retrieving userID for user ${username}" 
    user_id=$(curl "${CURL_FLAGS}" -X GET "https://keycloak.${cluster_fqdn}/admin/realms/master/users?q=username:${username}&exact=true" -H "Authorization: Bearer ${jwt_token}" | jq -r '.[0].id')
    if [ "$user_id" == "null" ]; then
        set +x
        echo "Failed to fetch user ID from Keycloak."
        exit 1
    fi
    echo -e "Username ${username} has ID of ${user_id}"
}

#KC get all users: 
# Usage: getkcUsers <cluster_fqdn> <jwt_token>
function getkcUsers() {
  local cluster_fqdn=$1
  local jwt_token=$2
  echo "${CYAN}Retrieving all Keycloak users ${NC}"
  echo "| Username      | Email          | UID                  |"
  curl "${CURL_FLAGS}" -X GET https://keycloak.${CLUSTER_FQDN}/admin/realms/master/users -H "Authorization: Bearer ${jwt_token}"|jq -r '.[] | select(.username and .email and .id) | "| \(.username) | \(.email) | \(.id)"'
}


# Usage: delete_keycloak_user <username> <cluster_fqdn> <admin_token>
function delete_keycloak_user() {
    local username=$1
    local admin_token=$3
    local cluster_fqdn=$2

    # Fetch user ID by username
    local userid=$(get_keycloak_user_id "$username" "$cluster_fqdn" "$admin_token")

    response=$(curl "${CURL_FLAGS}" -o /dev/null -w "%{http_code}" -X DELETE "https://keycloak.${cluster_fqdn}/admin/realms/master/users/${userid}" \
        -H "Authorization: Bearer ${admin_token}")

    if [ "$response" -eq 204 ]; then
        echo "Keycloak user deleted successfully."
    else
        echo "Failed to delete Keycloak user. HTTP response code: $response"
        exit 1
    fi
}
