#!/bin/bash

# # Exit on error
# set -e

# Check if environment parameter is provided
if [ -z "$1" ]; then
    echo "Usage: ./deploy.sh <environment> <profile> <aws_region>"
    echo "Example: ./deploy.sh dev my-profile us-east-1"
    exit 1
fi

ENVIRONMENT_NAME=$1
PROFILE=$2
AWS_REGION=$3

export APP_NAME="anycompany-${ENVIRONMENT_NAME}"
export DEPLOYMENT_BUCKET="anycompany-${ENVIRONMENT_NAME}-config-artifacts-${AWS_REGION}"
export S3_CODE_SERVICE_FOLDER=$APP_NAME/$ENVIRONMENT_NAME/code/services

STACK_NAME="${APP_NAME}"
API_KEYS_SECRET_NAME="anycompany-${ENVIRONMENT_NAME}-api-keys"

if [ $ENVIRONMENT_NAME == "dev" ]
then
    export SUBNET_ID_NAME="a"
    export SECGRP_ID_NAME="b"
    export VPC_ENDPOINT_ID="c"
fi

echo "🚀 Starting deployment for ${STACK_NAME}..."

# ~~~~~~~ BUILD SAM APPLICATION ~~~~~~~

echo "🛠 Building SAM application..."
PAGER=cat sam build --template-file template.yml --use-container

# ~~~~~~~ DEPLOY TO AWS ~~~~~~~
echo "🚀 Deploying to AWS..."

sam deploy \
    --stack-name ${STACK_NAME} \
    --s3-bucket ${DEPLOYMENT_BUCKET} \
    --s3-prefix $S3_CODE_SERVICE_FOLDER \
    --parameter-overrides \
        AppName=${APP_NAME} \
        DeploymentEnvironment=${ENVIRONMENT_NAME} \
    --capabilities CAPABILITY_IAM \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset \
    --region ${AWS_REGION}

echo "✅ Deployment completed successfully!"