# #!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 @effndc
#
# SPDX-License-Identifier: Apache-2.0

# This extension will collect required credentials and configuration automatically from the orchestrator.

# Define variables for rapid re-use
## If not being executed on orchestrator node, define these variables manually for rapid re-use.
#CLUSTER_FQDN="a.cluster.domain"
#KC_ADMINUSER="admin"
#KC_ADMIN_PASSWORD="MyPassw0rd123!"

## If being executed directly on the Orchestrator node you can discover some variables by setting this to true:
AUTO_COLLECT_VARS=true


# user data -- will prompt for input when not pre-defined 
## Password complexity reuqirements can be viewed https://keycloak.${CLUSTER_FQDN}/admin/master/console/#/master/authentication/policies 
#ORG_ADMIN_PASS=MyInsecurePassw0rd!
# if static org name is desired then define variable below
#org_name=$1
#project_name=$2


# Collect FQDN:
if [ "${AUTO_COLLECT_VARS}" = "true" ]; then
    echo "Automatic collecting Admin credentials"
    CLUSTER_FQDN=$(kubectl get configmap -n orch-gateway kubernetes-docker-internal -o yaml | yq '.data.dnsNames' | head -1 | sed 's/^- //')
    echo -e "${CYAN}Cluster FQDN Detected as ${CLUSTER_FQDN} ${NC}"

    # Collect Keycloak Admin Password:
    KC_ADMINUSER=admin
    KC_ADMIN_PASSWORD="$(kubectl -n orch-platform get secret platform-keycloak -o jsonpath='{.data.admin-password}' | base64 -d)"
fi

# Flags for Curl
# default, recommended: -s = silent
CURL_FLAGS="-s" 
# for self signed-cert environments add --insecure
#CURL_FLAGS="-s --insecure" 

