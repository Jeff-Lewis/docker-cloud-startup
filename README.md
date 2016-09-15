# Docker Cloud Startup

## What

This repo provides a Docker Cloud stack that spawns ["Bring Your Own Host"](https://docs.docker.com/docker-cloud/infrastructure/byoh/) nodes as EC2 instances in an AWS autoscaling group. Each EC2 instance registers itself as a Docker Cloud node with sensible default EC2 tags and Docker Cloud labels.

[![Deploy to Docker Cloud](https://files.cloud.docker.com/images/deploy-to-dockercloud.svg)](https://cloud.docker.com/stack/deploy/)

The "Deploy to Cloud" button above may be used to quickly get up and running. Refer to the comments in `docker-cloud.yml` for configuration details.

When deployed, the service will upload a launch script to the configured s3 bucket. Then it creates a CloudFormation stack based on `cloud-formation-template.json`, passing in various parameters sourced from the configuration.

When an EC2 instance launches, a user data shell script fetches and executes the script at `s3://$S3_BUCKET/docker-cloud-startup/$CLOUDFORMATION_STACK_PREFIX-$UUID/script.sh`. This script is responsible for registering the EC2 instance as a BYOH node and setting tags and labels. 

### EC2 Tags and BYOH Node Labels

The `UUID`, `Docker ID username`, and `Node Cluster Name` tags will always be set on every ec2 instance if launched successfully (these are standard Docker Cloud tags). Every BYOH node will also be labeled with `Cluster=<cfn-stack-name>`.

Use the `TAGS` configuration to specify custom EC2 tags. Any tags that begin with "Docker-Cloud-" are automatically applied as labels to the Docker Cloud node.

### Stack Redeployment

After a node has launched, the final step in the script is to redeploy any stacks specified in the config file. It's possible a redeployment may fail if one is currently in progress. There is currently no workaround for this.

### AWS Credentials

The AWS credentials you configure the service with will need to have s3 write access to the bucket you configure, as well as access for creating CloudFormation stacks. Here is a sample policy you may use. Replace `${S3_BUCKET}` with the configured bucket name:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "iam:CreateRole",
        "iam:PutRolePolicy",
        "iam:PassRole",
        "iam:CreateInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "ec2:CreateSecurityGroup",
        "autoscaling:CreateLaunchConfiguration",
        "autoscaling:CreateAutoScalingGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "cloudformation:UpdateStack",
        "cloudformation:DeleteStack"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::${S3_BUCKET}"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": ["arn:aws:s3:::${S3_BUCKET}/*"]
    }
  ]
}
```

_If you don't wish to allow the `iam:*` actions, then you must configure the service with a role name to use. Ditto for security groups._

### Create AWS Resources Manually

You may also create the same autoscaling resources without deploying a Docker Cloud stack. Just execute the following.

Launch in EC2 Classic:

```bash
docker run --rm -it \
  -e DOCKER_USER=<your_docker_username> \
  -e API_KEY=<your_docker_cloud_api_key> \
  -e AWS_ACCESS_KEY_ID=******************** \
  -e AWS_SECRET_ACCESS_KEY=******************** \
  -e S3_BUCKET=<s3_bucket> \
  -e AWS_REGION=us-east-1 \
  -e REDEPLOY_STACKS=foo,bar \
  -e AVAILABILITY_ZONES=us-east-1d,us-east-1b,us-east-1c \
  timehop/docker-cloud-startup:latest
```

Launch in a VPC:

```bash
docker run --rm -it \
  -e DOCKER_USER=<your_docker_username> \
  -e API_KEY=<your_docker_cloud_api_key> \
  -e AWS_ACCESS_KEY_ID=******************** \
  -e AWS_SECRET_ACCESS_KEY=******************** \
  -e S3_BUCKET=<s3_bucket> \
  -e AWS_REGION=us-east-1 \
  -e KEYPAIR_NAME=<keypair_name> \
  -e VPC_ID=<vpc_id> \
  -e SUBNETS=<csv_subnets> \
  -e INSTANCE_TYPE=t2.micro \
  -e REDEPLOY_STACKS=foo,bar \
  -e TAGS='Key=Docker-Cloud-IsVPC,Value=true' \
  timehop/docker-cloud-startup:latest
```

## Why

At [Vidsy](http://vidsy.co) and [Timehop](https://timehop.com) we wanted to use Docker Cloud, but also benefit from the controls and features of AWS.

## Details

### cfn-create-stack.sh

- Executed by the Docker Cloud service.
- Creates a CloudFormation stack with autoscaling resources.

### script.sh

- Executed on EC2 during launch as part of cloud-init (ie: UserData).
- Installs `docker-cloud-cli` and `aws-cli`.
- Sets environment variables for Docker Cloud authentication.
- Executes the `byo` CLI command to register new instance as Docker Cloud node.
- Tags EC2 instance with UUID.
- Waits for Docker Cloud node deployment to finish.
- Tags Docker Cloud node with `Cluster=<cfn-stackname>`.
- Tags Docker Cloud node with EC2 tags prefixed with `Docker-Cloud-`.
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
