# !/bin/bash

echo "#"
echo "# Check for Applications Synced state:"
echo "#"
kubectl get applications -A | grep -E -v 'Synced'

echo "#"
echo "#"
echo "#" 
echo "# Check for Applications Healthy state:"
kubectl get applications -A | grep -E -v 'Healthy'

echo "#"
echo "#"
echo "#"
echo "# Check pods for running state:"
kubectl get pods -A | grep -E -v 'Completed|1/1|2/2|3/3|4/4|5/5'

