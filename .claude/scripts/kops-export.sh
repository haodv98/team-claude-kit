#!/bin/bash
CLUSTER=$1
echo "Exporting kubecfg for $CLUSTER..."
kops export kubecfg --name="$CLUSTER" --admin
