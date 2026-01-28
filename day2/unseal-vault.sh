#!/usr/bin/env bash
# Unseal Vault instance running in Kubernetes
echo "Checking vault status"
# Get the 'Sealed' status
SEALED_STATUS=$(kubectl -n orch-platform exec vault-0 -- vault status 2>/dev/null | grep '^Sealed' | awk '{print $2}')

if [[ "$SEALED_STATUS" == "false" ]]; then
	echo "Vault is unsealed."
else
	echo "Vault is sealed, would you like to unseal it? (y/n)"
	read -r REPLY
	if [[ "$REPLY" =~ ^[Yy]$ ]]; then
		echo "Unsealing Vault..."
		kubectl -n orch-platform get secret vault-keys -o yaml | yq .data.vault-keys | base64 -d | jq -r '.keys[]' | xargs -n1 kubectl -n orch-platform exec -it vault-0 -- vault operator unseal
		# Check status again
		FINAL_STATUS=$(kubectl -n orch-platform exec vault-0 -- vault status | grep '^Sealed' | awk '{print $2}')
		if [[ "$FINAL_STATUS" == "false" ]]; then
			echo "Vault is now unsealed."
		else
			echo "Vault is still sealed. Please check for errors."
		fi
	else
		echo "Unseal operation cancelled."
	fi
fi
