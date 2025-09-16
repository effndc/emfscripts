#!/usr/bin/env bash
# shellcheck disable=SC2086
# Version 2024ww37.5
set -euo pipefail

# How to use:
# Script must be executed with -h or other flag to perform desired actionss

# Remove commenting to debug 
# set -x
# Define empty variables, for rapid re-usability you can input values here
NODE_BMC_IP="172.16.0.254"
NODE_BMC_USER="root"
NODE_BMC_PWD="calvin"
CLUSTER_FQDN="a.tiberedge.com"
#CLUSTER_FQDN="staging04.espdstage.infra-host.com"
NICSLOT=""

# For easy iteration through hosts you can also excute from CLI by commenting out above
# and un-commenting, run as './scriptname.sh CLUSTER_FQDN NODE_BMC_USER NODE_BMC_PWD NICSLOT NODE_BMC_IP'
#NODE_BMC_IP="$5"
#NICSLOT=$4"
#NODE_BMC_USER="$2"
#NODE_BMC_PWD="$3"
#CLUSTER_FQDN="$1"

# Sleep time for racadm tasks - setting too short and subsequent tasks in series may fail
t=5
# Sleep time to check for long running tasks
t2=30
# How long should netcat wait to verify connectivity -- change for slow networks
t3=1

# iDRAC reference:  https://www.dell.com/support/manuals/en-us/idrac9-lifecycle-controller-v4.x-series/idrac_4.00.00.00_racadm/racadm-subcommand-details?guid=guid-3e09aba8-6e2c-4fd9-9a17-d05f2596dbac&lang=en-us
#
# Do not edit below
##############################################################################
LOGIN="-r ${NODE_BMC_IP} -u ${NODE_BMC_USER} -p ${NODE_BMC_PWD} --nocertwarn"
TINK_FQDN=tinkerbell-nginx.${CLUSTER_FQDN}
IPXE_EFI="https://${TINK_FQDN}/tink-stack/signed_ipxe.efi"
# verify racadm is present and exit if not
if ! command -v racadm >/dev/null 2>&1; then
    echo '!!! ERROR: ✗ racadm command not found, please install or add to path and try again.'
    exit 1
  else
    echo '___ ✓ racadm is present -- continuing'
  fi
# Verify netcat is present so we can use it to validate host inputs
if ! command -v nc >/dev/null 2>&1; then
    echo '!!! ERROR: ✗ netcat not avaialble to verify inputs'
    exit 1
  else
    echo '___ ✓ netcat is present -- continuing'
  fi
# verify lib ssl is present as needed for racadm
isLibsslPresent=$(ldconfig -p | grep -c "libssl.so")
  if [ ${isLibsslPresent} -eq 0 ]; then
    echo '!!! ERROR: ✗ libssl.so is not present, please check your OS to install openssl-devel or libssl-dev' 
  else
    echo "___ ✓ libssl.so dependency for racadm satisfied  -- continuing"
  fi

# Prompt user to confirm before proceeding
user_confirmation () {
  read -p '??? Does this appear correct? (y/n) :  ' answer 
  if [[ ! $answer =~ ^[yn]$ ]]; then
      echo '>>> Invalid input' >&2
      exit 1
  fi
  if [ "$answer" = "y" ]; then
      echo '>>> Continuing...'
  else
      echo '>>> User Cancelled'
      exit 0
  fi
  }

# Prompt user for idrac variables
prompt_user_idrac () {
  # check if iDRAC data already present
  if [ -z "${NODE_BMC_IP}" ]; then  
    echo ""
    read -p '??? What is the IP address or FQDN (DNS Name) for your Dell iDRAC? :  ' NODE_BMC_IP
    read -p '??? Please input your iDRAC user name (e.g. root) :  ' NODE_BMC_USER
    read -p '??? Please input your iDRAC password (e.g. calvin) :  ' NODE_BMC_PWD
    echo ""
  
    # Expand  RACADM Login command
    LOGIN="-r ${NODE_BMC_IP} -u ${NODE_BMC_USER} -p ${NODE_BMC_PWD} --nocertwarn"
    if nc -w ${t3} -z ${NODE_BMC_IP} 443 2>/dev/null; then
       echo "!! ${NODE_BMC_IP} ✓  REACHABLE!"
    else
       echo "!! ${NODE_BMC_IP} ✗ UNREACHABLE!!  Check settings and try again."
       exit
    fi
    echo -e "\n Login command for iDRAC is: racadm ${LOGIN}\n"
    user_confirmation
    echo ""
  fi
   echo "" 
  }

# Prompt user for orchestrator variables
prompt_user_orchestrator () {
  # check if orchestrator data already present
  if [ -z "${CLUSTER_FQDN}" ]; then
    echo ">>> Orchestrator details required to retrieve certificates and configure boot target for onboarding" 
    read -p '??? Please input your Orchestrator DNS base URL (e.g. pdmdev01.espdstage.infra-host.com, excluding the web-ui. from URL) :  ' CLUSTER_FQDN
  # Expand variables
  TINK_FQDN=tinkerbell-nginx.${CLUSTER_FQDN}
  IPXE_EFI="https://${TINK_FQDN}/tink-stack/signed_ipxe.efi"
  if nc -w ${t3} -z ${TINK_FQDN} 443 2>/dev/null; then
      echo "!! ${TINK_FQDN} ✓  REACHABLE!"
    else
      echo "!! ${TINK_FQDN} ✗ UNREACHABLE!!  Check settings and try again."
      exit
    fi
  # RACADM Login
  echo -e "\n Configuring to boot system from ${IPXE_EFI}\n"
  user_confirmation
  fi
    echo ""
  }

# Obtain certs from Orch nginx
get_orch_certs() {
  prompt_user_orchestrator;
  echo 'WARNING: current directory will be used as working directory, existing local copies of certificates will be overwritten  ' 
  user_confirmation
  echo -e ">>> Getting certificates from ${TINK_FQDN} and storing locally\n"
  wget https://"${TINK_FQDN}"/tink-stack/keys/db.der  --no-check-certificate -O ${CLUSTER_FQDN}-db.der
  wget https://"${TINK_FQDN}"/tink-stack/keys/Full_server.crt  --no-check-certificate -O ${CLUSTER_FQDN}-Full_server.crt
  }

# Configure EN BIOS System Security
import_bios_certs() {
  prompt_user_idrac
  echo ">>> Importing certificates into ${NODE_BMC_IP}"
  racadm ${LOGIN} bioscert import -t 2 -k 0 -f ${CLUSTER_FQDN}-db.der
  sleep $t
  #racadm ${LOGIN} bioscert view --all
  racadm ${LOGIN} httpsbootcert import -i 1 -f ${CLUSTER_FQDN}-Full_server.crt
  sleep $t
  echo ">>> Setting Boot URL to ${IPXE_EFI}"
  racadm ${LOGIN} set BIOS.HttpDev1Settings.HttpDev1Uri "${IPXE_EFI}"
  #racadm ${LOGIN} httpsbootcert view -i 1
  activate_settings
  }

# Configure BIOS security
set_bios_security() {
  # Reference https://www.dell.com/support/manuals/en-us/poweredge-xr12/pexr12_bios_ism_pub/system-security?guid=guid-24e63dd7-d56c-4146-a871-217d22f1faab&lang=en-us 
  prompt_user_idrac
  echo ">>> Configuring SecureBoot on ${NODE_BMC_IP}"
  enable_secureboot
  sleep $t
  echo "> Setting BIOS.syssecurity.SecureBootMode UserMode"
  racadm ${LOGIN} set BIOS.syssecurity.SecureBootMode UserMode
  sleep $t
  echo "> Setting BIOS.syssecurity.SecureBootPolicy Custom"
  racadm ${LOGIN} set BIOS.syssecurity.SecureBootPolicy Custom
  sleep $t
  echo "> Setting BIOS.syssecurity.TpmSecurity On"
  racadm ${LOGIN} set BIOS.syssecurity.TpmSecurity On
  sleep $t
  echo "> Setting BIOS.syssecurity.Tpm2Hierarchy Enabled"
  racadm ${LOGIN} set BIOS.syssecurity.Tpm2Hierarchy Enabled
  sleep $t
  activate_settings
  }

# disable secure boot
disable_secureboot() {
  prompt_user_idrac
  echo ">>> Disabling SecureBoot on ${NODE_BMC_IP}"
  user_confirmation
  echo "> Setting BIOS.syssecurity.SecureBoot Disabled"
  racadm ${LOGIN} set BIOS.syssecurity.SecureBoot Disabled
  }

# enable secure boot
enable_secureboot() {
  prompt_user_idrac
  echo ">>> Enabling SecureBoot on ${NODE_BMC_IP}"
  user_confirmation
  echo "> Setting BIOS.syssecurity.SecureBoot Enabled"
  racadm ${LOGIN} set BIOS.syssecurity.SecureBoot Enabled 
  }

# Configure BIOS HTTP boot
set_bios_network() {
  prompt_user_orchestrator
  prompt_user_idrac
  echo ">>> Configuring HTTPS Boot on ${NODE_BMC_IP}"
  echo '>>> Please review list of network cards to select for HTTPSboot configuration '
  echo '!!! Selected network interface must have connectivity with DHCP and routing in place '
  racadm ${LOGIN} hwinventory nic | grep NIC
  echo 
  echo "--------------------------------------------------"
  read -p '??? Please specify target NIC.Slot.slot#-port# (e.g. NIC.Slot.2-1) or NIC.Slot.slot.slot#-partition#-port# (e.g. NIC.Slot.4-1-1) for HTTPS Boot assignment as reported in iDRAC inventory :  ' NICSLOT
  echo ""
  echo ">>> Enabling HTTP Boot Device 1"
  racadm ${LOGIN} set BIOS.NetworkSettings.HttpDev1EnDis Enabled
  sleep $t
  echo ">>> Assigning HTTP Boot Device 1 to ${NICSLOT}"
  racadm ${LOGIN} set BIOS.HttpDev1Settings.HttpDev1Interface "${NICSLOT}"
  sleep $t
  echo ">>> Setting Boot URL to ${IPXE_EFI}"
  racadm ${LOGIN} set BIOS.HttpDev1Settings.HttpDev1Uri "${IPXE_EFI}"
  sleep $t
  echo ">>> Enabling HTTP Boot TLS Verification"
  racadm ${LOGIN} set BIOS.HttpDev1TlsConfig.HttpDev1TlsMode OneWay
  sleep $t
  activate_settings
  }

# Set one-time boot order for onboarding
uefi_http_boot() {
  prompt_user_idrac
  echo -e '>>> Setting one time boot order to HTTPS Boot then rebooting system to start onboarding'
  echo ""
  racadm ${LOGIN} set iDRAC.serverboot.firstbootdevice UEFIHttp
  #racadm ${LOGIN} set BIOS.OneTimeBoot.OneTimeUefiBootSeqDev NIC.HttpDevice.1-1
  #racadm ${LOGIN} set BIOS.BiosBootSettings.SetBootOrderEn Disk.SATAEmbedded.A-1,NIC.HttpDevice.1-1
  #racadm ${LOGIN} set BIOS.BiosBootSettings.UefiBootSeq Disk.SATAEmbedded.A-1,NIC.HttpDevice.1-1
  sleep $t
  }

# Collect hardware inventory
get_hw_detail() {
  prompt_user_idrac
  echo " ----------------------------------------------------------- "
  racadm ${LOGIN} getsysinfo | grep -E 'Firmware|BIOS|Service|Svc'
  echo " ----------------------------------------------------------- "
  racadm ${LOGIN} hwinventory | grep -E '^GUID|^UUID'
  echo " ----------------------------------------------------------- "
  echo "Network Card Inventory:" 
  racadm ${LOGIN} hwinventory nic | grep NIC
  echo " ----------------------------------------------------------- "
  }

# Create reboot job to apply iDRAC changes
activate_settings(){
  P=""
  echo ">>> Activating iDRAC configuration changes"
  prompt_user_idrac
  JOB=$(racadm ${LOGIN} jobqueue create BIOS.Setup.1-1 -r pwrcycle -s TIME_NOW -e TIME_NA | tee /dev/tty | grep "Commit JID"| awk -F'[=]' '{print $2}' |  tr -d '[ ]\r\n$')
  JOBID=$(echo ${JOB}|tr -d '[ ]\r\n$')
  sleep $t
  echo "Checking job status"
  echo -e ">>> Reporting job status every $t2 seconds: Job ${JOBID}"
  while [[ $P -lt 100 ]]; do
    P=$(racadm ${LOGIN} jobqueue view -i "${JOBID}" | grep "Percent Complete" | awk -F "[][]" '{print $2}')
    echo -e "<<< Job is ${P} % Complete"
    sleep $t2
    done
    echo ">>> Settings applied <<< "  
  }

# Clear TPM
clear_sec_settings() {
  prompt_user_idrac
  echo ">>> Clearing TPM on ${NODE_BMC_IP}"
  racadm ${LOGIN} set BIOS.syssecurity.Tpm2Hierarchy Clear
  }

# Power on node
host_powerup() {
  prompt_user_idrac
  echo '>>> Powering server on'
  racadm ${LOGIN} serveraction powerup
  }

# Power on node
host_reset() {
  prompt_user_idrac
  echo '>>> Hard reseting server'
  racadm ${LOGIN} serveraction hardreset
  }

# Powercycle node
host_powercycle() {
  prompt_user_idrac
  echo '>>> Powercycling server'
  racadm ${LOGIN} serveraction powercycle
  }

# Import certs and set boot URI for new onboard target
update_node() {
  clear_sec_settings
  get_orch_certs
  import_bios_certs
  host_powercycle
  echo "< Waiting 2 minutes for reboot to load dependencies"
  sleep 120
  uefi_http_boot
  host_powercycle
  echo "> Node should attempt to HTTP boot for onboarding <"
  }

# All steps to configure for onboarding
configure_node_for_onboarding() {
  echo ">>> NOTE: You will be prompted for user input throughout the process <<< "
  host_powerup
  prompt_user_orchestrator
  prompt_user_idrac
  # disabled to not enable secureboot
  #set_bios_security
  set_bios_network
  get_orch_certs
  import_bios_certs
  host_powercycle
  echo "< Waiting 2 minutes for reboot to load dependencies"
  sleep 120
  uefi_http_boot
  host_reset
  echo "> Node should attempt to HTTP boot for onboarding <"
  }

host_defaults() {
  echo
  echo "??? System will reboot into BIOS Setup, please use iDRAC virtual console to proceed"
  user_confirmation
  echo "-------------------------------------------------------------------------------------------------"
  echo "> 1.  Click System BIOS, select Default button on bottom, confirm as needed, click Finish"
  echo "> 2.  Click iDRAC Settings, scroll down and select appropriate Reset options and confirm as needed"
  echo "> 3.  Confirm to reboot system to apply changes"
  echo "-------------------------------------------------------------------------------------------------" 
  prompt_user_idrac
  echo " >>> Setting system to boot to BIOS"
  racadm ${LOGIN} set iDRAC.serverboot.firstbootdevice BIOS
  host_reset
  }

# Help info
help() {
  echo -e "iDRAC BIOS Script utility functions\n"
  echo -e "WARNING: No input verification is performed, please proceed with caution."
  echo -e "!! All actions will disrupt any operational state on targeted servers and may result in data loss !!"
  echo -e "!! Press return/enter after responding to each prompt !!"
  echo
  echo -e "Syntax: ${0##*/} [-c|-u|-r|-p|-d|-i|-h]"
  echo -e "-c (configure)  : Configure Edge Node BIOS for bootup -- run configure against new hosts -- Configures takes ~15 minutes total"
  echo -e "-u (updated)    : Update a previously onboarded host for a new target Orchestrator instance with new certs and boot URI"
  echo -e "-r (reset)      : Reset Tpm2Hierarchy for re-provisioning"
  echo -e "-p (powercycle) : Set HTTPBoot and Power cycle edge node"
  echo -e "-d (defaults)   : Set iDRAC to factory defaults but preserve user and network settings"
  echo -e "-n (network)    : Change configured HTTPboot nework interface & reboot to onboard to new Edge Platform" 
  echo -e "-i (inventory)  : Collect hardware inventory from system" 
  echo -e "-z (insecureboot): Disable secureboot for testing purposes such as virtual media"
  echo -e "-s (secureboot) : (re-)Enable Secureboot"
  echo -e "-h (help)       : Print this help"
  echo
  echo -e "* To prepare a server that has not been previously provisioned use the -c (configure) task "
  echo -e "* To update a re-provision a previously onboarded node with the same Edge Platform instance\n and use option -p (powercycle)"
  echo -e "* To update a previously provisioned node to onboard with a new instance of Edge Platform,\n use option -n (network) "
  }

while getopts "hcurpdnizs" option; do
  case $option in
    h) 
      help
      ;;
    c)
      echo "You have chosen to fully configure a node for onboarding, this will require multiple reboots and take ~15 minutes"
      configure_node_for_onboarding
      ;;
    u)
      echo "You have chosen to update a nodes configuration to re-onboard with the same or a different target orcehstrator"
      update_node
      ;;
    r)
      echo "You have chosen to reset the TPM settings"
      clear_sec_settings
      activate_settings
      ;;
    p)
      echo "You have chosen to reboot the node for HTTP boot and onboarding with the previously configured orchestrator"
      host_powerup
      sleep $t2
      uefi_http_boot
      sleep $t2
      host_powercycle
      ;;
    d)
      echo "You have chosen to reboot the node to manually reset the BIOS or iDRAC settings to defaults"
      host_defaults
      ;;
    n) 
      echo "You have chosen to change the configured HTTP network device and to set the target orcehstrator"
      clear_sec_settings
      set_bios_network
      update_node
      ;;
    i)
      echo "You have requested a hardware inventory"
      get_hw_detail
      ;;
    s)
     # enable secure boot
     prompt_user_orchestrator
     prompt_user_idrac
     enable_secureboot
     activate_settings
     get_orch_certs
     import_bios_certs
     uefi_http_boot
     host_powercycle
     ;;
    z)
      disable_secureboot
      activate_settings
      uefi_http_boot
      sleep $t2
      host_powercycle
      ;;
    \?)
      echo ">>> Error: Invalid option"
      echo "Usage: $(basename "$0") [-h] [-c] [-u] [-r] [-p] [-d] [-n] [-i] [-s] [-z]"
      exit 1
      ;;
  esac
  done
echo 
echo 
echo "| Informational: "
echo -e "| Must be ran with flag, execute with ${0##*/} -h for help"
echo '| All actions will disrupt any operational state on targeted servers and may result in data loss !!'
echo "/////// END OF SCRIPT ///////"
