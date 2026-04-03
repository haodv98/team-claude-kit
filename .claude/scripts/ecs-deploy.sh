#!/bin/bash
CLUSTER=$1
SERVICE=$2
TAG=$3
echo "Deploying $TAG to ECS Cluster: $CLUSTER, Service: $SERVICE..."
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --force-new-deployment
