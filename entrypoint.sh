#!/bin/sh

set -e

[ -z "$AWS_S3_BUCKET" ] && (echo "AWS_S3_BUCKET ($AWS_S3_BUCKET) is not set. Quitting."; exit 1)
[ -z "$AWS_ACCESS_KEY_ID" ] && (echo "AWS_ACCESS_KEY_ID is not set. Quitting."; exit 1)
[ -z "$AWS_SECRET_ACCESS_KEY" ] && (echo "AWS_SECRET_ACCESS_KEY is not set. Quitting."; exit 1)
[ -z "$AWS_REGION" ] && AWS_REGION="us-east-1"

PROFILE="s3-sync-action"

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile $PROFILE
aws configure set aws_secret_access_key "$AWS_ACCESS_KEY_SECRET" --profile $PROFILE
aws configure set region $AWS_REGION --profile $PROFILE
aws configure set output "text" --profile $PROFILE

cat ~/.aws/credentials

# Sync using our dedicated profile and suppress verbose messages.
# All other flags are optional via the `args:` directive.
aws s3 sync ${SOURCE_DIR:-.} s3://${AWS_S3_BUCKET}/${DEST_DIR} --profile ${PROFILE} --no-progress
