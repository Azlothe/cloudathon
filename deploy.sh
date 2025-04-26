#!/bin/bash

# # Exit on error
# set -e

# Check if environment parameter is provided
if [ -z "$1" ]; then
    echo "Usage: ./deploy.sh <environment> <aws_region>"
    echo "Example: ./deploy.sh dev us-east-1"
    exit 1
fi

ENVIRONMENT_NAME=$1
AWS_REGION=$2

export APP_NAME="ac-${ENVIRONMENT_NAME}-b2"
export DEPLOYMENT_BUCKET="anycompany-${ENVIRONMENT_NAME}-config-artifacts-${AWS_REGION}"
export S3_CODE_SERVICE_FOLDER=$APP_NAME/$ENVIRONMENT_NAME/code/services

STACK_NAME="${APP_NAME}"
API_KEYS_SECRET_NAME="anycompany-${ENVIRONMENT_NAME}-api-keys"

if [ $ENVIRONMENT_NAME == "dev" ]
then
    export SUBNET_ID_NAME=""
    export SECGRP_ID_NAME=""
    export VPC_ENDPOINT_ID=""
    export ACCOUNT_ID="606215262039"
fi

ECR_NAME="${APP_NAME}"
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_NAME}"

echo "🚀 Starting deployment for ${STACK_NAME}..."


# 1. Ensure ECR repository exists
ensure_ecr_repo() {
  echo "Checking if ECR repository exists..."

  # Try to describe the repository
  aws ecr describe-repositories --repository-names ${APP_NAME} --region ${AWS_REGION} > /dev/null 2>&1

  # If the describe command failed (i.e., the repo doesn't exist), create the repository
  if [ $? -ne 0 ]; then
    echo "ECR repository does not exist. Creating repository..."
    aws ecr create-repository --repository-name ${APP_NAME} --region ${AWS_REGION}
    echo "ECR repository created: ${APP_NAME}"
  else
    echo "ECR repository ${APP_NAME} already exists."
  fi
}
ensure_ecr_repo &


# 3. Log in to ECR
(
  echo "🔐 Logging in to ECR..."
  aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
) &

# 4. Prepare Docker buildx builder (only once)
(
  echo "🔧 Ensuring docker buildx builder is ready..."
  if ! docker buildx inspect sam-builder > /dev/null 2>&1; then
    docker buildx create --name sam-builder --use
  else
    docker buildx use sam-builder
  fi
) &

wait
echo "✅ Pre-requirements done."


# ~~~~~~~ BUILD SAM APPLICATION ~~~~~~~

echo "🛠 Building SAM application..."
PAGER=cat sam build --template-file template.yml --use-container

# ~~~~~~~ PARALLEL DOCKER BUILDS ~~~~~~~
echo "📦 Building Docker images in parallel..."

build_docker_image() {
  TASK_DIR=$1
  IMAGE_TAG=$2
  FULL_TAG="${ECR_URI}:${IMAGE_TAG}"

  echo "Building ${IMAGE_TAG}..."
  (
    cd "./src/${TASK_DIR}" || exit 1
    docker buildx build --platform linux/arm64 -t "${FULL_TAG}" . --push
  )
}

IMAGE_TAG="hello-world"
build_docker_image "hello-world" ${IMAGE_TAG} &
PID1=$!

wait $PID1

echo "✅ Docker images built and pushed."

# ~~~~~~~ DEPLOY TO AWS ~~~~~~~
echo "🚀 Deploying to AWS..."

sam deploy \
    --stack-name ${STACK_NAME} \
    --s3-bucket ${DEPLOYMENT_BUCKET} \
    --s3-prefix $S3_CODE_SERVICE_FOLDER \
    --parameter-overrides \
        AppName=${APP_NAME} \
        DeploymentEnvironment=${ENVIRONMENT_NAME} \
        ImageTag=${IMAGE_TAG} \
        ECRUri=${ECR_URI} \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset \
    --region ${AWS_REGION}


echo "✅ Deployment completed successfully!"