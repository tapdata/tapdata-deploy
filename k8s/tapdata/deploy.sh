#!/bin/bash

WORK_DIR=$(pwd)

DEPLOY_CONFIG_HOME=$(cd "$(dirname "$0")/../../" && pwd)
HELM_REPO="$DEPLOY_CONFIG_HOME/deploy-on-kubernetes"
TAPDATA_NAMESPACE="tapdata"

function install() {
    helm install tapdata "$HELM_REPO" \
      --namespace "$TAPDATA_NAMESPACE" \
      --create-namespace \
      -f "$HELM_REPO/values-huawei.yaml"

    INGRESSIP=$(kubectl -n "$TAPDATA_NAMESPACE" describe  ingress tapdata-ingress | grep "kubernetes.io/elb.ip" | awk '{print $2}')
    echo "exec command to watch deploy status: kubectl -n $TAPDATA_NAMESPACE get pods -w"
    echo "When deploy done open http://$INGRESSIP to access TapData console"
}

function upgrade() {
  helm upgrade tapdata "$HELM_REPO" \
     -n "$TAPDATA_NAMESPACE" \
    -f "$HELM_REPO/values-huawei.yaml"
}

function uninstall() {
    helm uninstall tapdata -n "$TAPDATA_NAMESPACE"
}

function dryRun() {
    helm install tapdata "$HELM_REPO" \
      --namespace "$TAPDATA_NAMESPACE" \
      --dry-run --debug \
      -f "$HELM_REPO/values-huawei.yaml"
}

if [ "$1" = 'i' ] || [ "$1" = 'install' ] ; then
    install
elif [ "$1" = 'uninstall' ]; then
    uninstall
elif [ "$1" = 'dryRun' ]; then
    dryRun
elif [ "$1" = 'upgrade' ]; then
  upgrade
else
    echo "deploy.sh <command>"
    echo "   install: Install tapdata using current kubernetes context"
    echo "   uninstall: uninstall tapdata using current kubernetes context"
    echo "   dryRun: print deployment config for kubernetes"
fi