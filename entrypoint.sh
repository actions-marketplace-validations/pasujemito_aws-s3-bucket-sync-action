#!/bin/sh

set -e

[ -z "$AWS_S3_BUCKET" ] && (echo "AWS_S3_BUCKET is not set. Quitting."; exit 1)
[ -z "$AWS_ACCESS_KEY_ID" ] && (echo "AWS_ACCESS_KEY_ID is not set. Quitting."; exit 1)
[ -z "$AWS_SECRET_ACCESS_KEY" ] && (echo "AWS_SECRET_ACCESS_KEY is not set. Quitting."; exit 1)
[ -z "$AWS_REGION" ] && AWS_REGION="us-east-1"

[ -z "$S3_WEBSITE_INDEX" ] && S3_WEBSITE_INDEX="index.html" && (echo "S3_WEBSITE_INDEX set to default: $S3_WEBSITE_INDEX")
[ -z "$S3_WEBSITE_ERROR" ] && S3_WEBSITE_ERROR="error.html" && (echo "S3_WEBSITE_ERROR set to default: $S3_WEBSITE_ERROR")

PROFILE="s3-sync-action"
S3_WEBSITE_POLICY <<- EOM
{
    "Version": "2012-10-17",
    "Id": "PolicyForPublicWebsiteContent",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::webapp-epod-tracker/static/*"
        }
    ]
}
EOM

# Setup AWS Credentials
aws configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}" --profile $PROFILE
aws configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}" --profile $PROFILE
aws configure set region ${AWS_REGION} --profile $PROFILE
aws configure set output "text" --profile $PROFILE

# Create bucket if one does not exist
aws s3api head-object --bucket "${AWS_S3_BUCKET}" --key index.html > /dev/null || aws s3api create-bucket --bucket ${AWS_S3_BUCKET} --region ${AWS_REGION} --create-bucket-configuration LocationConstraint=${AWS_REGION} > /dev/null

# Sync files
aws s3 sync ${SOURCE_DIR:-.} s3://${AWS_S3_BUCKET}/${DEST_DIR} --profile ${PROFILE} --no-progress --acl public-read --follow-symlinks --delete

# Create website
aws s3 website s3://${AWS_S3_BUCKET}/${DEST_DIR} --index-document ${S3_WEBSITE_INDEX} --error-document ${S3_WEBSITE_ERROR}

# Update Bucket Policy
aws a3api put-bucket-policy --bucket --policy ${S3_WEBSITE_POLICY}

echo "${APP_URL:"http://$AWS_S3_BUCKET.s3-website-$AWS_REGION.amazonaws.com/}"
