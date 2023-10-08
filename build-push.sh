#!/bin/bash

# Protect against harmful commands from executing if script fails
set -e

# Get the short SHA of the latest commit
commit_hash=$(git rev-parse --short HEAD)

# Login to Azure Container Registry
/opt/homebrew/bin/az acr login --name w255mids

# Build the Docker image for x86_64 architecture
docker build --platform linux/amd64 -t w255mids.azurecr.io/mnd476/project:$commit_hash .

# Push the Docker image to ACR
docker push w255mids.azurecr.io/mnd476/project:$commit_hash
