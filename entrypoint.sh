#!/bin/sh

set -e

cd ${GITHUB_WORKSPACE}

[ -z "$AWS_S3_BUCKET" ] && (echo "AWS_S3_BUCKET is not set. Quitting."; exit 1)
[ -z "$AWS_ACCESS_KEY_ID" ] && (echo "AWS_ACCESS_KEY_ID is not set. Quitting."; exit 1)
[ -z "$AWS_SECRET_ACCESS_KEY" ] && (echo "AWS_SECRET_ACCESS_KEY is not set. Quitting."; exit 1)

[ -z "$AWS_IAM_PROFILE" ] && AWS_IAM_PROFILE="s3-sync-action" && (echo "AWS_IAM_PROFILE set to default: $AWS_IAM_PROFILE")
[ -z "$AWS_REGION" ] && AWS_REGION="us-east-1" && (echo "AWS_REGION set to default: $AWS_REGION")
[ -z "$S3_WEBSITE_INDEX" ] && S3_WEBSITE_INDEX="index.html" && (echo "S3_WEBSITE_INDEX set to default: $S3_WEBSITE_INDEX")
[ -z "$S3_WEBSITE_ERROR" ] && S3_WEBSITE_ERROR="error.html" && (echo "S3_WEBSITE_ERROR set to default: $S3_WEBSITE_ERROR")
[ -z "$S3_WEBSITE_POLICY" ] && S3_WEBSITE_POLICY=$(cat <<-END
{
    "Version": "2012-10-17",
    "Id": "PolicyForPublicWebsiteContent",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": {
                "AWS": "$([ $CLOUDFRONT_AI ] && echo "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity $CLOUDFRONT_AI" || echo "*")"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$AWS_S3_BUCKET/${DEST_DIR:+$DEST_DIR/}*"
        }
    ]
}
END
)

# Setup AWS Credentials
aws configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}" --profile $AWS_IAM_PROFILE
aws configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}" --profile $AWS_IAM_PROFILE
aws configure set region ${AWS_REGION} --profile $AWS_IAM_PROFILE
aws configure set output "text" --profile $AWS_IAM_PROFILE

# Create bucket if one does not exists in the region
[ $AWS_REGION != "us-east-1" ] && REGION_ARGS="--create-bucket-configuration LocationConstraint=$AWS_REGION"
aws s3api head-object --bucket $AWS_S3_BUCKET --key $S3_WEBSITE_INDEX >/dev/null && echo "Skipping bucket creation, already exists!" || aws s3api create-bucket --bucket $AWS_S3_BUCKET --region $AWS_REGION $REGION_ARGS > /dev/null

# Sync files
aws s3 sync ${SOURCE_DIR:-.} s3://$AWS_S3_BUCKET/$DEST_DIR --profile $AWS_IAM_PROFILE --no-progress

# Create website if enabled and apply public policy
if $WEBSITE
then
    aws s3 website s3://$AWS_S3_BUCKET --index-document ${DEST_DIR:+$DEST_DIR\\}$S3_WEBSITE_INDEX --error-document ${DEST_DIR:+$DEST_DIR\\}$S3_WEBSITE_ERROR
    aws s3api put-bucket-policy --bucket $AWS_S3_BUCKET --policy "$S3_WEBSITE_POLICY"
    
    echo "Webiste URL: http://$AWS_S3_BUCKET.s3-website-$AWS_REGION.amazonaws.com/"
    echo "::set-output name=output_website_url::http://$AWS_S3_BUCKET.s3-website-$AWS_REGION.amazonaws.com/"
fi

# Generate pre-signed URLs for file
# TODO: Unmask AccountTokenId to display private URL
[ -z "$URL_EXPIRY" ] && URL_EXPIRY="300" && (echo "URL_EXPIRY set to default: $URL_EXPIRY")
PRESIGNED_URL=$(aws s3 presign s3://$AWS_S3_BUCKET${DEST_DIR:+/}/$S3_WEBSITE_INDEX  --expires-in $URL_EXPIRY)
echo "::set-output name=output_presigned_url::$PRESIGNED_URL"
