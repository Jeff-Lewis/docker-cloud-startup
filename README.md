# Docker Cloud Startup

### What

This repo provides a Docker Cloud stack that spawns ["Bring Your Own Host"](https://docs.docker.com/docker-cloud/infrastructure/byoh/) nodes as EC2 instances in an AWS autoscaling group. Each EC2 instance registers itself as a Docker Cloud node with sensible default EC2 tags and Docker Cloud labels.

[![Deploy to Docker Cloud](https://files.cloud.docker.com/images/deploy-to-dockercloud.svg)](https://cloud.docker.com/stack/deploy/)

The "Deploy to Cloud" button above can be used to get up and running. You will need to configure it with the following details:

1. Your Docker Cloud username.
1. A Docker Cloud API key (Managed under account [settings](https://cloud.docker.com/_/account)).
1. AWS region to deploy nodes into.
1. AWS credentials with privileges to create CloudFormation stacks.
1. AWS availability zones to launch EC2 instances into.
1. An AWS IAM role to launch EC2 instances with.
1. An AWS security group(s) to launch EC2 instances with which exposes 6783/tcp, 6783/udp, and 2375/tcp.
1. An AWS ssh keypair to launch EC2 instances with.
1. An AWS vpc subnet(s) to launch EC2 instances into.
1. A AWS S3 bucket to host the startup script.
1. A unique name for the AWS CloudFormation stack.
1. Any tags you may wish to launch EC2 instances with.

**Note:** Currently the service _must_ be configured with VPC subnets, IAM role, security group, and ssh keypair.

When deployed, this stack will upload `script.sh` with _public-read_ permissions to `s3://$S3_BUCKET/docker-cloud-startup/$CLOUDFORMATION_STACK_NAME/script.sh`. Next it creates a CloudFormation stack from `cloud-formation-template.json`, passing in various parameters sourced from the environment.

When an EC2 instance launches, a user data shell script fetches and executes the script at `s3://$S3_BUCKET/docker-cloud-startup/$CLOUDFORMATION_STACK_NAME/script.sh`. This script is responsible for registering the EC2 instance as a BYOH node and setting tags and labels. 

### EC2 Tags and BYOH Node Labels

Aside from the EC2 tags you specify in the stack definition, a `Docker-Cloud-UUID` tag will always be set. Every BYOH node will also be labeled with the following instance details: `availabilityZone`, `instanceId`, `privateIp`, and `region`.

Use the `$TAGS` env var to specify custom EC2 tags. Any tags that begin with "Docker-Cloud-" are automatically applied as labels to the corresponding BYOH node.

### Execute Not as a Docker Cloud Service

```bash
docker run --rm -it \
  -e DOCKER_USER=<your_docker_username> \
  -e API_KEY=<your_docker_cloud_api_key> \
  -e AWS_REGION=<aws_region> \
  -e AWS_ACCESS_KEY_ID=*********************** \
  -e AWS_SECRET_ACCESS_KEY==*********************** \
  -e AVAILABILITY_ZONES=<comma_separated_availability_zones> \
  -e IAM_ROLE=<iam_role_name> \
  -e SECURITY_GROUPS=<comma_separated_security_group_ids> \
  -e KEYPAIR_NAME=<aws_keypair_name> \
  -e SUBNETS=<comma_separated_subnet_ids> \
  -e S3_BUCKET=<writeable_s3_bucket> \
  -e CLOUDFORMATION_STACK_NAME=<unique_name> \
  -e DEPLOYMENT_TIMEOUT=2m \
  -e AMI_ID=ami-2d39803a \
  -e INSTANCE_TYPE=t2.micro \
  -e DESIRED_CAPACITY=1 \
  -e TAGS="Key=Foo,Value=Bar Key=Biz,Value=Baz" \
  timehop/docker-cloud-startup:latest
```

### Why

At [Vidsy](http://vidsy.co) and [Timehop](https://timehop.com) we wanted to use Docker Cloud, but also benefit from the controls and features of AWS.

## Details

### cfn-create-stack.sh

- Executed by the Docker Cloud service.
- Creates a CloudFormation stack with autoscaling resources.

### script.sh

- Executed on EC2 during launch.
- Installs `docker-cloud-cli` and `aws-cli`.
- Sets environment variables for Docker Cloud authentication.
- Uses "Bring Your Own Node" CLI command to register new instance as Docker Cloud node.
- Waits for Docker Cloud node deployment to finish.
- Adds Docker Cloud UUID as a tag on the AWS instance.
- Retrieves EC2 instance tags.
- Adds certain tags as a Docker Cloud node label.
- Redeploys stacks.
- Delete all installed packages and Bash history.

### Supported Linux Distros

Has been tested on: Ubuntu 14.04, RHEL 7, CentOS 7 and Fedora 23.

### To-Do

Look at any [open issues](https://github.com/vidsy/tutum-startup/issues?utf8=%E2%9C%93&q=is%3Aissue+is%3Aopen+label%3ATo-Do) labeled as `to-do`.

### Use Cases

- ["Cost efficient CI infrastructure with AWS, Docker and Tutum"](https://blog.fabfuel.de/2016/01/27/cost-efficient-ci-infrastructure-with-aws-docker-and-tutum/) by @fabian

### Notes

- Help improve this repo!
- Feel free to ping me (`@revett`) on the [Tutum community Slack](https://tutum-community.slack.com/) with any questions.
- [MIT License (MIT)](https://opensource.org/licenses/MIT).

### Credits

- [@revett](https://github.com/revett)
- [@jskeates](https://github.com/jskeates)
- [@stevenjack](https://github.com/stevenjack)
- [@kevin-cantwell](https://github.com/kevin-cantwell)
