#!/bin/sh

set -e

[ -z "$AWS_S3_BUCKET" ] && (echo "AWS_S3_BUCKET is not set. Quitting."; exit 1)
[ -z "$AWS_ACCESS_KEY_ID" ] && (echo "AWS_ACCESS_KEY_ID is not set. Quitting."; exit 1)
[ -z "$AWS_SECRET_ACCESS_KEY" ] && (echo "AWS_SECRET_ACCESS_KEY is not set. Quitting."; exit 1)
[ -z "$AWS_REGION" ] && AWS_REGION="us-east-1"

[ -z "$S3_WEBSITE_INDEX" ] && S3_WEBSITE_INDEX="index.html" && (echo "S3_WEBSITE_INDEX set to default: $S3_WEBSITE_INDEX")
[ -z "$S3_WEBSITE_ERROR" ] && S3_WEBSITE_ERROR="error.html" && (echo "S3_WEBSITE_ERROR set to default: $S3_WEBSITE_ERROR")

PROFILE="s3-sync-action"

aws configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}" --profile $PROFILE
aws configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}" --profile $PROFILE
aws configure set region ${AWS_REGION} --profile $PROFILE
aws configure set output "text" --profile $PROFILE

cat ~/.aws/credentials

# Sync using our dedicated profile and suppress verbose messages.
# All other flags are optional via the `args:` directive.
aws s3 sync ${SOURCE_DIR:-.} s3://${AWS_S3_BUCKET}/${DEST_DIR} --profile ${PROFILE} --no-progress --acl public-read --follow-symlinks --delete
aws s3 website s3://${AWS_S3_BUCKET}/${DEST_DIR} --index-document ${S3_WEBSITE_INDEX} --error-document ${S3_WEBSITE_ERROR}

echo "http://$AWS_S3_BUCKET.s3-website-$AWS_REGION.amazonaws.com/"
