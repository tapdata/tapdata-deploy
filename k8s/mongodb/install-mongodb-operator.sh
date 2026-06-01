#!/bin/bash

# Install MongoDB Community Operator
# Usage: bash install-mongodb-operator.sh [REGISTRY_URL]
# If REGISTRY_URL is provided, all MongoDB images will be pulled from that registry

REGISTRY_URL="${1:-}"

helm repo add mongodb https://mongodb.github.io/helm-charts
helm repo update

HELM_SET_ARGS="--set operator.watchNamespace=\"*\""

if [ -n "$REGISTRY_URL" ]; then
  echo "Configuring MongoDB operator to use image registry: $REGISTRY_URL"
  HELM_SET_ARGS="${HELM_SET_ARGS} --set registry.operator=${REGISTRY_URL}"
  HELM_SET_ARGS="${HELM_SET_ARGS} --set registry.agent=${REGISTRY_URL}"
  HELM_SET_ARGS="${HELM_SET_ARGS} --set registry.versionUpgradeHook=${REGISTRY_URL}"
  HELM_SET_ARGS="${HELM_SET_ARGS} --set registry.readinessProbe=${REGISTRY_URL}"
  HELM_SET_ARGS="${HELM_SET_ARGS} --set mongodb.repo=${REGISTRY_URL}"
fi

eval "helm install community-operator mongodb/community-operator \
  --namespace mongodb \
  --create-namespace \
  ${HELM_SET_ARGS}"
