#!/bin/bash

helm repo add mongodb https://mongodb.github.io/helm-charts
helm repo update

helm install community-operator mongodb/community-operator \
  --namespace mongodb \
  --create-namespace \
  --set operator.watchNamespace="*"


