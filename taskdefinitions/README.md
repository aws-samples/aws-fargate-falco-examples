# Amazon ECS Task Definitions

This directory includes sample task definitions for the patterns discussed in
the [container image](/../../tree/main/containerimages/) directory on to Amazon
ECS for AWS Fargate.

## Prerequisites

1. The container images discussed in the [container image](/../../tree/main/containerimages/)
   directory have been built and pushed to Amazon ECR.
2. An Amazon ECS Cluster and the relevant Amazon VPCs and subnets exist.
3. An IAM Role to be used as the [Amazon ECS Execution
   Role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html)
   exists.

### Configuration Files

When running these containers locally in the [container
image](/../../tree/main/containerimages/) directory we are mounting a `falco.yaml` and
`falco_rules.local.yaml` file into each container. I felt these configuration
files should not be embedded into the container image allowing the user to
customize them for each environment, such as adding new Falco rules. There are
various methods of passing configuration files into Amazon ECS Tasks, such as
Init Containers or leveraging SSM Parameter Store. In this example we will use
the init container pattern demonstrated in this
[repository](https://github.com/aws-samples/amazon-ecs-configmaps-example). This
Init Container pattern stores the configuration files in an S3 Bucket, with the
Init Container (instructed via environment variables) downloading the
configuration files at runtime.

> Ensure you use a unique bucket name, this bucket name is also referenced in
> the task definitions so will also need to be updated there.

```bash
UNIQUE_BUCKET_NAME=falcotestbucket123

# Make the S3 Bucket
aws s3 mb \
  s3://$UNIQUE_BUCKET_NAME

# Copy Local Rules file
aws s3 cp \
  falco_rules.local.yaml \
  s3://$UNIQUE_BUCKET_NAME/falco_rules.local.yaml

# Copy Embedded Binaries Falco Config
aws s3 cp \
  eb_falco.yaml \
  s3://$UNIQUE_BUCKET_NAME/eb_falco.yaml

# Copy Mounted Binaries Falco Config
aws s3 cp \
  mb_falco.yaml \
  s3://$UNIQUE_BUCKET_NAME/mb_falco.yaml
```

### Task IAM Role

An [ECS Task IAM
Role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)
refers to AWS Credentials that are passed in to the ECS Task that are used by
the workload to access AWS resources. There are 2 requirements for the AWS
Credentials in these example tasks.

1) Credentials for the Init Container to download the configuration files from
   S3.
2) Credentials for the `logshipper` binary that is includes in the Mounted
   Binaries pattern to send Falco logs to Amazon CloudWatch.

For simplicity we will only create 1 IAM Role and use it for both the embedded
binaries and the mounted binaries pattern. This doesn't follow least privilege
best practise as the embedded binaries pattern doesn't need the CloudWatch roles
and can be removed.

> Ensure the IAM Account, Log Group, and S3 Bucket Names have been updated in
> the json IAM Policy documents.

```bash
export AWS_PAGER=""

aws iam create-role \
  --role-name ECSTaskFalcoRole \
  --assume-role-policy-document file://iam/trust_policy_ecs_task.json

aws iam create-policy \
  --policy-name ECSTaskFalcoRoleS3 \
  --policy-document file://iam/iam_policy_s3.json

aws iam create-policy \
  --policy-name ECSTaskFalcoRoleCloudwatch \
  --policy-document file://iam/iam_policy_cloudwatch.json

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::111222333444:policy/ECSTaskFalcoRoleS3 \
  --role-name ECSTaskFalcoRole

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::111222333444:policy/ECSTaskFalcoRoleCloudwatch \
  --role-name ECSTaskFalcoRole
```

## Deploying and Running the ECS Tasks

Once the prerequisites have been met and the configuration files uploaded to an
S3 Bucket the the tasks can be started.

### Embedded Binaries

Running the Embedded Binaries Pattern on Amazon ECS with the Run Task Command.

> Ensure the Container Image, S3 Bucket and IAM Roles have been updated in the
> json Task Defintion.

```bash
export CLUSTER_NAME=falco-demo

# Register the Task Definition
aws ecs \
  register-task-definition \
  --cli-input-json file://embeddedbinaries_taskdef.json

# Create the Cloudwatch Log Group. This is for all entries to STOUT
# the Falco logs will be merged with the Workload Logs.
aws logs \
  create-log-group \
  --log-group-name /aws/ecs/service/embeddedbinaries

# Start a single task with Run Task.
# Replace the subnet and security group values in this command.
# For this dummy workload the security group does not need any ingress rules.
aws ecs \
  run-task \
  --count 1 \
  --launch-type FARGATE \
  --task-definition falcoembeddedbinaries \
  --cluster $CLUSTER_NAME \
  --network-configuration "awsvpcConfiguration={subnets=["subnet-0e9843372c879637a"],securityGroups=[sg-024e364124959fa0e],assignPublicIp=DISABLED}"
```

You can monitor the logs by heading the Amazon CloudWatch Logs Console and
browsing the `/aws/ecs/service/embeddedbinaries` log group.

To clean up the Task:

```bash
# Retrieve the Task Arn
aws ecs \
  list-tasks \
  --cluster $CLUSTER_NAME
{
    "taskArns": [
        "arn:aws:ecs:eu-west-1:111222333444:task/falco-demos/d3fb0b37b9424904bd1c926062159271"
    ]
}

# Stop the Running Task
aws ecs \
  stop-task \
  --cluster $CLUSTER_NAME \
  --task "arn:aws:ecs:eu-west-1:111222333444:task/falco-demos/d3fb0b37b9424904bd1c926062159271"

# Delete the Log Group
aws logs \
  delete-log-group \
  --log-group-name /aws/ecs/service/embeddedbinaries

# Deregister the Task Definition
aws ecs \
  deregister-task-definition \
  --task-definition falcoembeddedbinaries:1
```

### Mounted Binaries

Running the Mounted Binaries Pattern on Amazon ECS with the Run Task Command.

> Ensure the Container Image, S3 Bucket and IAM Roles have been updated in the
> json Task Defintion.

```bash
export CLUSTER_NAME=falco-demo

# Register the Task Definition
aws ecs \
  register-task-definition \
  --cli-input-json file://mountedbinaries_taskdef.json

# Create the Cloudwatch Log Group. This is for all entries to STOUT
# the Falco logs will be merged with the Workload Logs.
aws logs \
  create-log-group \
  --log-group-name /aws/ecs/service/mountedbinaries

# Start a single task with Run Task.
# Replace the subnet and security group values in this command.
# For this dummy workload the security group does not need any ingress rules.
aws ecs \
  run-task \
  --count 1 \
  --launch-type FARGATE \
  --task-definition falcomountedbinaries \
  --cluster $CLUSTER_NAME \
  --network-configuration "awsvpcConfiguration={subnets=["subnet-0e9843372c879637a"],securityGroups=[sg-024e364124959fa0e],assignPublicIp=DISABLED}"
```

You can monitor the Workload logs by heading to the Amazon CloudWatch Logs
Console and browsing the `/aws/ecs/service/mountedbinaries` log group. You can
monitor the Falco Logs sent by the `logshipper` binary by browsing to the log
group `/aws/ecs/service/falco_alerts`.

To clean up the Task:

```bash
# Retrieve the Task Arn
aws ecs \
  list-tasks \
  --cluster $CLUSTER_NAME
{
    "taskArns": [
        "arn:aws:ecs:eu-west-1:111222333444:task/falco-demos/681b8aa3e8d3408a86a9416799ab674a"
    ]
}

# Stop the Running Task
aws ecs \
  stop-task \
  --cluster $CLUSTER_NAME \
  --task "arn:aws:ecs:eu-west-1:111222333444:task/falco-demos/681b8aa3e8d3408a86a9416799ab674a"

# Delete the Log Groups
aws logs \
  delete-log-group \
  --log-group-name /aws/ecs/service/mountedbinaries

aws logs \
  delete-log-group \
  --log-group-name /aws/ecs/service/falco_alerts

# Deregister the Task Definition
aws ecs \
  deregister-task-definition \
  --task-definition falcomountedbinaries:1
```

## Clean Up

The final bits to clean up from this guide is the ECS Task IAM Role and the S3
Bucket.

```bash
BUCKET_NAME=falcotestbucket123

# This command deletes the S3 Bucket and all of the objects within.
aws s3 \
  rb \
  s3://$BUCKET_NAME \
  --force
```

Cleaning up the IAM Role and relevant policies.

```bash
export AWS_PAGER=""

aws iam detach-role-policy \
  --policy-arn arn:aws:iam::111222333444:policy/ECSTaskFalcoRoleS3 \
  --role-name ECSTaskFalcoRole

aws iam detach-role-policy \
  --policy-arn arn:aws:iam::111222333444:policy/ECSTaskFalcoRoleCloudwatch \
  --role-name ECSTaskFalcoRole

aws iam delete-policy \
  --policy-arn arn:aws:iam::111222333444:policy/ECSTaskFalcoRoleS3

aws iam delete-policy \
  --policy-arn arn:aws:iam::111222333444:policy/ECSTaskFalcoRoleCloudwatch

aws iam delete-role \
  --role-name ECSTaskFalcoRole
```