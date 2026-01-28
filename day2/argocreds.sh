#!/bin/bash
# Print ArgoCD initial admin password
ArgoPWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Argo username is: admin"
echo "ArgoCD Password:  $ArgoPWD"

