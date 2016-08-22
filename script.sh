#!/bin/bash

# --
# Usage:
#
# ./script.sh $DOCKERCLOUD_AUTH $DEPLOYMENT_TIMEOUT
# --

# --
# Stop script if any command fails and run _cleanup() function
# --

set -e
trap _cleanup ERR

# --
# Functions
# --

function _cleanup {
  printf "[docker-cloud-startup] ERROR - STOPPING EARLY.\n"
}

function _error {
  printf "[docker-cloud-startup]   -> Error: $1.\n"
}

function _finished {
  printf "[docker-cloud-startup] SCRIPT COMPLETE.\n"
}

function _ok {
  printf "[docker-cloud-startup]   -> ok.\n"
}

function _output {
  printf "[docker-cloud-startup] $1\n"
}

function _result {
  printf "[docker-cloud-startup]   -> $1\n"
}

# --
# Validate number of arguments
# --

_output "Checking arguments..."

if [ "$#" -ne 2 ]; then
  _error "illegal number of parameters"
  exit 1
else
  _ok
fi

# --
# START
# --

# --
# Version-specific variables
# --

_output "Setting final variables..."

METADATA_SERVICE_URI="http://169.254.169.254/latest/meta-data"
_result "METADATA_SERVICE_URI: \"$METADATA_SERVICE_URI\""

DOCKER_CLOUD_CLI_VERSION="1.0.1"
_result "DOCKER_CLOUD_CLI_VERSION: \"$DOCKER_CLOUD_CLI_VERSION\""

AWS_CLI_VERSION="1.9.20"
_result "AWS_CLI_VERSION: \"$AWS_CLI_VERSION\""

_ok

# --
# Find OS kind
# --

_output "Finding OS..."

OS_KIND="unknown"
if which apt-get > /dev/null; then
  OS_KIND="debian"
elif which yum > /dev/null; then
  OS_KIND="fedora"
fi
_result "OS: \"$OS_KIND\""

_ok

# --
# Install dependencies
# --

_output "Installing dependencies..."

case "$OS_KIND" in
  debian)
    locale-gen en_GB.UTF-8
    apt-get update
    apt-get install -y python-pip jq curl
    ;;
  fedora)
    echo "en_GB.UTF-8" > /etc/locale.conf

    # Fedora doesn't have Python pre-installed
    yum install -y python curl

    # pip & jq aren't in the yum repos
    curl -O https://bootstrap.pypa.io/get-pip.py
    python get-pip.py
    curl -Lo /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
    chmod ugo+x /usr/bin/jq

    # We also need to configure sudo for the agent install to work
    echo "Defaults:root !requiretty" >> /etc/sudoers.d/91-cloud-sudoers-requiretty
    chmod 440 /etc/sudoers.d/91-cloud-sudoers-requiretty
    ;;
  unknown)
    echo "This OS is not supported"
    exit 2
    ;;
esac

_ok

# --
# Install CLI apps
# --

_output "Installing CLI apps..."

pip install -q docker-cloud==$DOCKER_CLOUD_CLI_VERSION awscli==$AWS_CLI_VERSION

_ok

# --
# Set Docker Cloud env vars
# --

_output "Setting Docker Cloud environment variables..."

export DOCKERCLOUD_AUTH=$1
_result "DOCKERCLOUD_AUTH: \"Basic xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\""

_ok

# --
# Set AWS env vars
# --

_output "Setting AWS environment variables..."

export AWS_DEFAULT_REGION=$(curl -f ${METADATA_SERVICE_URI}/placement/availability-zone | sed 's/.$//')
_result "AWS_DEFAULT_REGION: \"$AWS_DEFAULT_REGION\""

_ok


# --
# INPUT variables
# --

_output "Setting input variables..."

DEPLOYMENT_TIMEOUT=$2
_result "DEPLOYMENT_TIMEOUT: \"$DEPLOYMENT_TIMEOUT\""

_ok

# --
# Register node
# --

_output "Registering node..."

BYO_COMMAND=$(docker-cloud node byo | sed -n 4p | sed -e 's/^[ \t]*//')
_result "\"$BYO_COMMAND\""
eval $BYO_COMMAND

_ok

# --
# Set node UUID env var now that agent has been installed
# --

_output "Setting Docker Cloud node UUID..."

export NODE_UUID=$(cat /etc/dockercloud/agent/dockercloud-agent.conf | jq -r .UUID)
_result "NODE_UUID: \"$NODE_UUID\""

_ok

# --
# Wait for node to be deployed
# --

_output "Wait for node to be deployed..."

timeout $DEPLOYMENT_TIMEOUT bash -c "while [ \"\$(docker-cloud node inspect $NODE_UUID | jq -r .state)\" != \"Deployed\" ]; do sleep 5; done;"
if [ $? != 0 ]; then _error "node never came up"; exit 2; fi

_ok

# --
# Set node tags in docker cloud based on EC2 tags (tag must include "Docker-Cloud")
# --

_output "Add docker cloud node tags..."

INSTANCE_ID=$(curl -f ${METADATA_SERVICE_URI}/instance-id)
_result "INSTANCE_ID: \"$INSTANCE_ID\""

# E.g.: Docker-Cloud-NodeType=Worker
EC2_TAGS=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" | jq -r '.Tags | map(select(.Key | contains("Docker-Cloud"))) | .[].Key+"="+.[].Value')
for TAG in $EC2_TAGS
do
  docker-cloud tag add -t $TAG $NODE_UUID
  _result "TAG: \"$TAG\""
done

INSTANCE_IDENTITY=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .)
TAG="region=$(echo -n $INSTANCE_IDENTITY | jq -r .region)"
docker-cloud tag add -t $TAG $NODE_UUID
_result "TAG: \"$TAG\""
TAG="privateIp=$(echo -n $INSTANCE_IDENTITY | jq -r .privateIp)"
docker-cloud tag add -t $TAG $NODE_UUID
_result "TAG: \"$TAG\""
TAG="availabilityZone=$(echo -n $INSTANCE_IDENTITY | jq -r .availabilityZone)"
docker-cloud tag add -t $TAG $NODE_UUID
_result "TAG: \"$TAG\""
TAG="instanceId=$(echo -n $INSTANCE_IDENTITY | jq -r .instanceId)"
docker-cloud tag add -t $TAG $NODE_UUID
_result "TAG: \"$TAG\""

_ok

# --
# Set node UUID as AWS tag
# --

_output "Add AWS tags..."

INSTANCE_ID=$(curl -f ${METADATA_SERVICE_URI}/instance-id)
_result "INSTANCE_ID: \"$INSTANCE_ID\""

aws ec2 create-tags --resources $INSTANCE_ID --tags Key="Docker-Cloud-UUID",Value=$NODE_UUID

_ok

# --
# Cleanup instance
# --

_output "Cleanup instance..."
unset AWS_DEFAULT_REGION DOCKERCLOUD_USER DOCKERCLOUD_APIKEY NODE_UUID
pip uninstall docker-cloud awscli -y
case "$OS_KIND" in
  debian)
    apt-get purge -y python-pip jq
    ;;
  fedora)
    pip uninstall pip -y
    rm /usr/bin/jq
    ;;
esac

# --
# Cleanup history
# --

_output "Cleanup history..."

cat /dev/null > ~/.bash_history && history -c

_ok

_finished