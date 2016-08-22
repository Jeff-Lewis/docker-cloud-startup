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

_output "Uploading user-data script..."

script_path="$S3_BUCKET/docker-cloud-startup/$CLOUDFORMATION_STACK_NAME/script.sh"
aws s3 cp --acl public-read script.sh "s3://$script_path"

DOCKERCLOUD_AUTH="Basic $(echo -n "$DOCKER_USER:$API_KEY" | base64)"
# We are forced to outsource the major portion of user data to an external location due to character length restrictions
read -d '' user_data << EOF || true
#!/bin/bash
curl -s https://s3.amazonaws.com/$script_path | bash -s "$DOCKERCLOUD_AUTH" ${DEPLOYMENT_TIMEOUT:-2m}
EOF

_result "user-data: \"https://s3.amazonaws.com/$script_path\""

_ok


_output "Creating Cloudformation stack..."

# Requires: $AWS_REGION, $AWS_ACCESS_KEY_ID, $AWS_SECRET_ACCESS_KEY,
# $CLOUDFORMATION_STACK_NAME, $KEYPAIR_NAME, $IAM_ROLE, $SECURITY_GROUPS, $AVAILABILITY_ZONES,
# $SUBNETS, $user_data
aws --region ${AWS_REGION} cloudformation create-stack \
  --stack-name "$CLOUDFORMATION_STACK_NAME" \
  --template-body file://cloud-formation-template.json \
  --capabilities CAPABILITY_IAM \
  --parameters ParameterKey=ImageId,ParameterValue=${AMI_ID:-ami-2d39803a} \
               ParameterKey=KeyPairName,ParameterValue=${KEYPAIR_NAME} \
               ParameterKey=IamInstanceProfile,ParameterValue=${IAM_ROLE} \
               ParameterKey=SecurityGroups,ParameterValue=\"${SECURITY_GROUPS}\" \
               ParameterKey=AvailabilityZones,ParameterValue=\"${AVAILABILITY_ZONES}\" \
               ParameterKey=Subnets,ParameterValue=\"${SUBNETS}\" \
               ParameterKey=InstanceType,ParameterValue=${INSTANCE_TYPE:-t2.micro} \
               ParameterKey=DesiredCapacity,ParameterValue=${DESIRED_CAPACITY:-1} \
               ParameterKey=UserData,ParameterValue="$(echo -n "$user_data" | base64)" \
  --tags Key=Name,Value=${CLOUDFORMATION_STACK_NAME} ${TAGS}

_ok

_finished