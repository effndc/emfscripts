# Day 2 Troubleshooting tools

This contains several scripts to help avoid having to go back to the user documentation for commont asks.

> NOTE: These scripts are only tested in an on-prem deployment and may need adaptation to work in cloud hosted. 

`health-check.sh` script just quickly shows any Applications or Pods that are in a suspicious state, it is a good sanity check if the Orchestrator does not appear to be working as expected. 

`argocreds.sh` retrieves the ArgoCD admin credentials that were randomly generated during install. 

`keycloak-pass.sh` retrieves the default keycloak admin password, as long as it was not manually changed in the keycloak interace it should work. 

`unseal-vault.sh` is to check if the Vault secret store is sealed and to unseal it, this must be performed if the Orchestrator node is rebooted.