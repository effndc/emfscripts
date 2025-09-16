#!/bin/bash
echo -e "\n ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "\n ## Please load certificates if not using auto-generated certs "
echo -e " ## Script will sleep for 60 seconds while waiting"
echo -e " ## See https://docs.openedgeplatform.intel.com/edge-manage-docs/main/deployment_guide/on_prem_deployment/on_prem_get_started/on_prem_install.html#prepare-tls-certificate-secret" 
# TODO: Add check for existence of secret: kubectl -n orch-gateway get secrets tls-orch
# Loop while the output of the command is "OutOfSync"
echo -e "\n ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "\n ## Please wait for further instructions ##"
echo -e "\n ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
while [[ "$(kubectl get applications -n onprem root-app | tail -1 | awk '{print $2}')" == "OutOfSync" ]]; do
    echo -e "\n$(date) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    kubectl get applications -A | grep -E -v 'Healthy'
    # Sleep for a while before checking again (e.g., 5 seconds)
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "✗  Install still in progress. Will check again in 30 seconds."
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    sleep 30
    echo -e "\n"
done
CLUSTER_FQDN=$(kubectl get configmap -n orch-gateway kubernetes-docker-internal -o yaml | yq '.data.dnsNames' | head -1 | sed 's/^- //')
KC_USER_NAME=admin
echo "✓ root-app in sync, installation should be complete"
echo "."
echo "."
echo "#######################"
echo "# You now need to confirm your DNS is configured to match the output of: generate_fqdn"
echo "# See: https://docs.openedgeplatform.intel.com/edge-manage-docs/main/deployment_guide/on_prem_deployment/on_prem_get_started/on_prem_install.html#dns-configuration"
echo "# Once DNS entries exist you are now able to proceed:"
echo -e "# You may now proceed to configure user access at https://keycloak.${CLUSTER_FQDN} ##"
KC_USER_PASSWORD=$(kubectl -n orch-platform get secret platform-keycloak -o jsonpath='{.data.admin-password}' | base64 -d)
echo "## Keycloak admin username is:  ${KC_USER_NAME}"
echo "## Keycloak admin password is:  ${KC_USER_PASSWORD}"
echo "## It is recommended to save this password, if you change this it cannot be retrieved! "
echo "## Please find relevant documentation here: https://docs.openedgeplatform.intel.com/edge-manage-docs/main/shared/shared_mt_overview.html"
echo "## In order to proceed you need accounts that have org-admin-group permissions" 
echo "## Please visit https://docs.openedgeplatform.intel.com/edge-manage-docs/main/shared/shared_iam_groups.html "
echo "#######################"
echo "# Once accounts are configured may access your Orchestrator at https://web-ui.${CLUSTER_FQDN}"