#!/bin/bash

# SPDX-FileCopyrightText: 2025 @effndc
#
# SPDX-License-Identifier: Apache-2.0

echo "Please review any of the listed applications or pods"
echo ""
echo "Out-of-sync Applications:"
kubectl get applications -A | grep -E -v 'Synced' 
echo "-----------------------------------------"
echo "-----------------------------------------"
echo "Unhealthy Applications:"
kubectl get applications -A | grep -E -v 'Healthy'
echo "-----------------------------------------"
echo "-----------------------------------------"
echo "Pods in mismatch state:"
kubectl get pods -A | grep -E -v 'Completed|1/1|2/2|3/3|4/4|5/5' 
