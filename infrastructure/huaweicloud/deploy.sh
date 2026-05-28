#!/bin/bash

WORK_DIR=$(pwd)

IAC_HOME=$(cd "$(dirname "$0")" && pwd)

function install() {
    terraform apply -var-file=terraform.tfvars
}

function uninstall() {

}

function get_kubeconfig() {
    terraform output -raw kubeconfig > ~/.kube/config-huawei
}
