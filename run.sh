#!/bin/bash

# Protects against harmful commands from executing if script fails
set -e

# Start Minikube
echo "Starting Minikube..."
minikube start

# Set docker env
echo "Setting up docker environment for Minikube..."
eval $(minikube docker-env)

# Build the Docker container
echo "Building Docker container..."
docker build -t project-container project

# Create namespace
echo "Creating namespace..."
kubectl create namespace w255

# Apply the k8s files
echo "Applying k8s deployment and service files..."
kubectl apply -f project/infra/deployment-redis.yaml -n w255
kubectl apply -f project/infra/service-redis.yaml -n w255
kubectl apply -f project/infra/deployment-pythonapi.yaml -n w255
kubectl apply -f project/infra/service-prediction.yaml -n w255

# Wait for the deployment to be rolled out
echo "Waiting for the deployment to be complete..."
kubectl rollout status deployment/pythonapi-project-deployment -n w255

# Port forward the deployment
echo "Port forwarding the deployment..."
kubectl port-forward deployment/pythonapi-project-deployment 8000:8000 -n w255 &

# Wait for port forward to be set up
sleep 5

# '/health' endpoint
echo "Testing '/health' endpoint"
curl -o /dev/null -s -w "%{http_code}\n" -X GET "http://localhost:8000/health"

# Clean up
echo "Killing the port-forward..."
kill %1

echo "Deleting the namespace..."
kubectl delete namespaces w255

echo "Stopping Minikube..."
minikube stop

