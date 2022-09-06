#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

echo "This script will push all 3 sets of images to ECR"
echo "The assumption is the relevant AWS credentials are available"
echo "and that the ECR repository has already been created"

echo "Enter AWS Region"
read AWS_REGION

echo "Enter AWS Account ID"
read AWS_ACCOUNT_ID

echo "Enter Desired Repository Name"
read ECR_REPO_NAME

for IMAGE in embeddedbinaries mountedbinaries mountedbinariesworkload sidecarptracefalco sidecarptraceworkload
do
 echo "Retagging Image"
 docker tag $IMAGE $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE

 echo "Pushing Image"
 docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE
done