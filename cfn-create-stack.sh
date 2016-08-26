#!/bin/bash

# --
# Usage:
#
# ./cfn-create-stack.sh
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
# Set up defaults
# --

UUID=$(cat /proc/sys/kernel/random/uuid | cut -d '-' -f 1)
CLOUDFORMATION_STACK_NAME=${CLOUDFORMATION_STACK_PREFIX:-docker-cloud-byoh}-${UUID}
AMI_ID=${AMI_ID:-ami-2d39803a}
INSTANCE_TYPE=${INSTANCE_TYPE:-m3.medium}
DESIRED_CAPACITY=${DESIRED_CAPACITY:-1}
DEPLOYMENT_TIMEOUT=${DEPLOYMENT_TIMEOUT:-2m}
DOCKERCLOUD_AUTH="Basic $(echo -n "$DOCKER_USER:$API_KEY" | base64)"
DOCKERCLOUD_NAMESPACE=${DOCKERCLOUD_NAMESPACE:-${DOCKER_USER}}

_output "Uploading startup script..."

script_path="${S3_BUCKET}/docker-cloud-startup/${CLOUDFORMATION_STACK_NAME}/script.sh"
aws s3 cp --acl public-read script.sh "s3://$script_path"

_result "\"https://s3.amazonaws.com/$script_path\""

_ok


_output "Creating Cloudformation stack..."

# We are forced to outsource the major portion of user data to an external location due 
# to character length restrictions of parameter fields.
read -d '' USER_DATA << EOF || true
#!/bin/bash
curl -s https://s3.amazonaws.com/$script_path | bash -s "${DOCKERCLOUD_AUTH}" ${DOCKERCLOUD_NAMESPACE} ${DEPLOYMENT_TIMEOUT}
EOF

aws --region ${AWS_REGION} cloudformation create-stack \
  --stack-name "${CLOUDFORMATION_STACK_NAME}" \
  --template-body file://cloud-formation-template.json \
  --capabilities CAPABILITY_IAM \
  --parameters ParameterKey=ImageId,ParameterValue=${AMI_ID} \
               ParameterKey=KeyPairName,ParameterValue=${KEYPAIR_NAME} \
               ParameterKey=IamInstanceProfile,ParameterValue=${IAM_ROLE} \
               ParameterKey=SecurityGroups,ParameterValue=\"${SECURITY_GROUPS}\" \
               ParameterKey=AvailabilityZones,ParameterValue=\"${AVAILABILITY_ZONES}\" \
               ParameterKey=VpcId,ParameterValue=\"${VPC_ID}\" \
               ParameterKey=Subnets,ParameterValue=\"${SUBNETS}\" \
               ParameterKey=InstanceType,ParameterValue=${INSTANCE_TYPE} \
               ParameterKey=DesiredCapacity,ParameterValue=${DESIRED_CAPACITY} \
               ParameterKey=UserData,ParameterValue="$(echo -n "$USER_DATA" | base64)" \
  --tags Key=Name,Value=${CLOUDFORMATION_STACK_NAME} ${TAGS}

_ok

_finished