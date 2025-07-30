#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

prompt_org () {
  # check if variables exist
  if [ -z "${org_name:-}" ]; then
    echo -e "${GREEN}"
    read -p '??? Provide short organization name :  ' org_name
    echo -e "${NC}"
  fi
  }

prompt_project () {
  # check if variables exist
  if [ -z "${project_name:-}" ]; then
    echo -e "${GREEN}"
    read -p '??? Provide short project name :  ' project_name
    echo -e "${NC}"
  fi
  }

prompt_org_admin_pass () {
  # check if variables exist
  if [ -z "${ORG_ADMIN_PASS+xxx}" ]; then
    echo -e "${CYAN} Org Admin account will be created as ${org_name}-admin"
    echo -e "${RED}"
    echo -e "Password complexity policy can be viewed at https://keycloak.${CLUSTER_FQDN}/admin/master/console/#/master/authentication/policies " 
    echo -e "${GREEN}"
    read -p '??? Provide requested user password :  ' ORG_ADMIN_PASS
    echo -e "${NC}"
  else
    echo -e "${CYAN}Organization admin will be created as ${org_name}-admin with password ${pass} ${NC}" 
  fi
  }
prompt_org_user_pass () {
  # check if variables exist
  if [ -z "${ORG_USER_PASS+xxx}" ]; then
    echo -e "${CYAN} Org Admin account will be created as ${org_name}-user"
    echo -e "${RED}"
    echo -e "Password complexity policy can be viewed at https://keycloak.${CLUSTER_FQDN}/admin/master/console/#/master/authentication/policies " 
    echo -e "${GREEN}"
    read -p '??? Provide requested user password :  ' ORG_USER_PASS
    echo -e "${NC}"
  else
    echo -e "${CYAN}Organization admin will be created as ${org_name}-admin with password ${pass} ${NC}" 
  fi
  }

# Prompt user for Orchestrator administrator details
prompt_orch_credentials () {
  # check if variables exist
  if [ -z "${KC_ADMIN_PASSWORD+xxx}" ]; then
    echo -e "${GREEN}"
    read -p ' What is your orchestrator cluster_fqdn? :  ' CLUSTER_FQDN
    echo -e "${CYAN}Password can be retrieved from orchestrator node: kubectl -n orch-platform get secret platform-keycloak -o jsonpath='{.data.admin-password}' | base64 -d ${NC}"
    echo -e "${GREEN}"
    read -p ' Please input Keycloak Administrator user name (e.g. admin) :  ' kc_admin
    read -p ' Please input your Keycloak Administrator password :  ' KC_ADMIN_PASSWORD
    echo -e "${NC}"
    if nc -w 2 -z keycloak.${CLUSTER_FQDN} 443 2>/dev/null; then
       echo -e "${CYAN}!! keycloak.${CLUSTER_FQDN}} ✓  REACHABLE!${NC}"
    else
       echo -e "${RED}!! keycloak.${CLUSTER_FQDN} ✗ UNREACHABLE!!  Check settings and try again.${NC}"
       exit
    fi
      echo "Proceeding"
  fi
  }