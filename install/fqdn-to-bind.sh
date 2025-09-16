#!/bin/bash
/usr/bin/generate_fqdn | head -n -2 | while read -r line;
  do
    echo "$line" | awk '{split($2, arr, "."); print $1, arr[1]}' | awk -v OFS='\t' '{print $2".a","3600","IN","A",$1}';
  done

