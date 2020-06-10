#!/bin/bash
# This script creates a secret and rolebindings needed for self-hosted runners.

set -e

function check_env() {
    if [ -z $(eval echo "\$$1") ]; then
        echo "Environment Variable $1 not found.  Exiting..."
        exit 1
    fi
}

check_env "ACTIONS_PAT"

if kubectl get namespaces actions > /dev/null; then
    echo "namespaces 'actions' already exists."
else
    kubectl create namespaces actions
fi


if kubectl -n actions get secrets self-hosted-runner-creds > /dev/null && [[ "$1" != "--force-update" ]]; then
    echo "secret 'self-hosted-runner-creds' already exist."
    exit 1
else
    envsubst "\$ACTIONS_PAT" < k8s_setup/authorize.yml | kubectl -n actions apply -f -
fi
