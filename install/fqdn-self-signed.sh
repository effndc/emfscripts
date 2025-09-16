#!/bin/bash
/usr/bin/generate_fqdn | head -n -2 | while read -r line;
  do
    echo "$line" | awk '{print "https://" $2}' ;
  done

