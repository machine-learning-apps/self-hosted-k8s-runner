#!/bin/bash
# This is a script to deploy the k8s self-hosted runner

set -e
cd $(dirname "$0")

function check_env() {
    if [ -z $(eval echo "\$$1") ]; then
        echo "Environment Variable $1 not found.  Exiting..."
        exit 1
    fi
}

export DEFAULT_IMAGE_NAME="github/k8s-actions-runner:latest"

check_env "ACTIONS_GITHUB_REPO"

if [ -z "$ACTIONS_DEPLOY_NAME" ]; then
    export ACTIONS_DEPLOY_NAME=`echo $ACTIONS_GITHUB_REPO | sed "s/\//-/"`
    echo "*** Warning: Environment Variable ACTIONS_DEPLOY_NAME not specified, defaulting to $ACTIONS_DEPLOY_NAME"
fi

if [ -z "$ACTIONS_IMAGE_NAME" ]; then
    export ACTIONS_IMAGE_NAME="$DEFAULT_IMAGE_NAME"
    echo "*** Warning: Environment Variable ACTIONS_IMAGE_NAME not specified, defaulting to $DEFAULT_IMAGE_NAME"
fi

# Refresh Deployment
envsubst "\$ACTIONS_GITHUB_REPO\$ACTIONS_IMAGE_NAME\$ACTIONS_DEPLOY_NAME" < deployment.yml | kubectl -n actions apply -f -
