#!/bin/bash
DNSSERVER=172.16.0.1
/usr/bin/generate_fqdn | head -n -2 | while read -r line;
  do
    HostDNS=$(echo "$line" | awk '{print $2}')
    HostIP=$(dig @"${DNSSERVER}" +short ${HostDNS}) 
    if [ -z "${HostIP}" ]; then
      echo -e " ✗    ${HostDNS} no IP address found!! "
      else
      echo -e " ✓    ${HostDNS} has IP address of ${HostIP}" 
    fi
  done
