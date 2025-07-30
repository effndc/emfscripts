# #!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0



# This extension will collect required credentials and configuration automatically from the orchestrator.

# Collect FQDN:
CLUSTER_FQDN=$(kubectl get configmap -n orch-gateway kubernetes-docker-internal -o yaml | yq '.data.dnsNames' | head -1 | sed 's/^- //')
echo Cluster FQDN Detected as ${CLUSTER_FQDN}

# Collect Keycloak Admin Password:
KC_ADMINUSER=admin
KC_ADMIN_PASSWORD=$(kubectl -n orch-platform get secret platform-keycloak -o jsonpath='{.data.admin-password}' | base64 -d)


