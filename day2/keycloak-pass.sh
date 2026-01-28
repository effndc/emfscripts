# !/bin/bash
# Script to get Keycloak admin password from Kubernetes secret
KC_ADMIN_PASSWORD=$(kubectl -n orch-platform get secret platform-keycloak -o jsonpath='{.data.admin-password}' | base64 -d)
echo Keycloak Password is:  ${KC_ADMIN_PASSWORD}
