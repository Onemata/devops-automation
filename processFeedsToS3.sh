#!/bin/bash

####  Validate that ENVIRONMENT VARIABLES are set

if [[ -z "${AWS_PROFILE_NAME_SQS}" ]] ; then
    echo "Please set AWS_PROFILE_NAME_SQS for location of SQS"
    exit 1
fi
if [[ -z "${SECRET_KEY_SQS}" ]] ; then
    echo "Please set SECRET_KEY_SQS for location of SQS"
    exit 1
fi
if [[ -z "${ACCESS_KEY_SQS}" ]] ; then
    echo "Please set ACCESS_KEY_SQS for location of SQS"
    exit 1
fi

if [[ -z "${AWS_PROFILE_NAME_SOURCE}" ]] ; then
    echo "Please set AWS_PROFILE_NAME_SOURCE for location of SQS"
    exit 1
fi
if [[ -z "${SECRET_KEY_SOURCE}" ]] ; then
    echo "Please set SECRET_KEY_SOURCE for location of SQS"
    exit 1
fi
if [[ -z "${ACCESS_KEY_SOURCE}" ]] ; then
    echo "Please set ACCESS_KEY_SOURCE for location of SQS"
    exit 1
fi

if [[ -z "${AWS_PROFILE_NAME_TARGET}" ]] ; then
    echo "Please set AWS_PROFILE_NAME_TARGET for location of SQS"
    exit 1
fi
if [[ -z "${SECRET_KEY_TARGET}" ]] ; then
    echo "Please set SECRET_KEY_TARGET for location of SQS"
    exit 1
fi
if [[ -z "${ACCESS_KEY_TARGET}" ]] ; then
    echo "Please set ACCESS_KEY_TARGET for location of SQS"
    exit 1
fi

if [[ -z "${SQS_URL}" ]] ; then
    echo "Please set SQS_URL for location of SQS"
    exit 1
fi

if [[ -z "${AWS_BUCKET_SOURCE}" ]] ; then
    echo "Please set AWS_BUCKET_SOURCE for location of source bucket"
    exit 1
fi

#if [[ -z "${AWS_PREFIX_SOURCE}" ]] ; then
#	echo "Please set AWS_PREFIX_SOURCE for location of source prefix"
#	exit 1
#fi

if [[ -z "${AWS_BUCKET_TARGET}" ]] ; then
    echo "Please set AWS_BUCKET_TARGET for location of target bucket"
    exit 1
fi
#if [[ -z "${AWS_PREFIX_TARGET}" ]] ; then
#	AWS_PREFIX_TARGET=${AWS_PREFIX_SOURCE}
#	#echo "Please set AWS_PREFIX_TARGET for location of target prefix"
#	#exit 1
#fi


#set -x
# Pause 10 Seconds before starting.
sleep 5

whoami
#pwd
#ls -ltra

#cp -v ./.boto ~/.boto
#cp -v ./onemata.json ~/onemata.json
mkdir -vp ~/.aws
#chown `whoami` ~/.boto ~/onemata.json

echo "[AWS_SQS]" >> ~/.aws/credentials
echo "aws_secret_access_key = ${SECRET_KEY_SQS}"  >> ~/.aws/credentials
echo "aws_access_key_id = ${ACCESS_KEY_SQS}" >> ~/.aws/credentials
echo "[AWS_SOURCE]" >> ~/.aws/credentials
echo "aws_secret_access_key = ${SECRET_KEY_SOURCE}"  >> ~/.aws/credentials
echo "aws_access_key_id = ${ACCESS_KEY_SOURCE}" >> ~/.aws/credentials
echo "[AWS_TARGET]" >> ~/.aws/credentials
echo "aws_secret_access_key = ${SECRET_KEY_TARGET}"  >> ~/.aws/credentials
echo "aws_access_key_id = ${ACCESS_KEY_TARGET}" >> ~/.aws/credentials

chmod -R 600 ~/.aws

#chmod ~/.boto ~/onemata.json
#
#gsServiceKeyFile=~/onemata.json
#
## Update the .boto file with the location of the onemata.json file
#sed -i "s|__GS_SERVICE_KEY_FILE__|${gsServiceKeyFile}|" ~/.boto
#
## Update the json file with the access keys and secret keys
#sed -i "s|__PROJECT_ID__|${GS_PROJECT_ID}|" ${gsServiceKeyFile}
#sed -i "s|__PRIVATE_KEY_ID__|${GS_PRIVATE_KEY_ID}|" ${gsServiceKeyFile}
#sed -i "s|__PRIVATE_KEY__|${GS_PRIVATE_KEY}|" ${gsServiceKeyFile}
#sed -i "s|__CLIENT_EMAIL__|${GS_CLIENT_EMAIL}|" ${gsServiceKeyFile}
#sed -i "s|__CLIENT_ID__|${GS_CLIENT_ID}|" ${gsServiceKeyFile}
#sed -i "s|__CLIENT_CERT__|${GS_CLIENT_CERT}|" ${gsServiceKeyFile}

# !!!! If these lines are uncommented, you will need to remove the log from AWS
#cat ~/.aws/credentials
#cat ${gsServiceKeyFile}
#cat ~/.boto
# Test access to Google Cloud
#gsutil version -l
#gsutil ls gs://brandify-onemata/

#spark-results/14206-us2/year=$YEAR/date=$YEAR-$MONTH

# Test access to Source S3 Location
#aws --profile AWS_SOURCE s3api list-objects --bucket ${AWS_BUCKET_SOURCE} --prefix "${AWS_PREFIX_SOURCE}" --query 'CommonPrefixes' --delimiter '/' --output text

# Test access to Target S3 Location
set -x
aws --profile AWS_TARGET s3api get-bucket-acl --bucket ${AWS_BUCKET_TARGET}  --output text

# Test access to Feeds Location for Checking the SQS
aws --profile AWS_SQS --region us-west-2 sqs get-queue-attributes --queue-url "${SQS_URL}" --attribute-names ApproximateNumberOfMessages --output text
set -


while [[ 0 -eq 0 ]]
do
        while read MessageBody ReceiptHandle Other
        do
                if [[ "${MessageBody}" != "None" ]] ; then
                        TargetObject="${MessageBody}"
                        #if [[ "$PREFIX_TARGET" != "" ]] ; then
                        #       TargetObject=${PREFIX_TARGET}/$MessageBody
                        #else
                        #       TargetOjbect=$MessageBody
                        #fi
                        #TargetObject=${MessageBody%Onemata_Mobile_Location_Data_*}${MessageBody#*Onemata_Mobile_Location_Data_}
                        #TargetObject="${MessageBody/_1_/_2_}"
                        echo "SourceObject:   $MessageBody"
                        echo "TargetObject:   $TargetObject"
                        echo "Handle:         $ReceiptHandle"
                        SourceFileSize=`aws --profile AWS_SOURCE  s3api list-objects --bucket ${AWS_BUCKET_SOURCE} --prefix "$MessageBody" --query 'Contents[*].{Size: Size}' --output text`
                        aws --profile AWS_SOURCE s3 cp s3://${AWS_BUCKET_SOURCE}/$MessageBody - | aws --profile AWS_TARGET s3 cp - s3://${AWS_BUCKET_TARGET}/$TargetObject
#                        aws --profile AWS_SOURCE s3 cp s3://${AWS_BUCKET_SOURCE}/$MessageBody - | gsutil cp - gs://${GS_URI}/$TargetObject
#                       TargetFileSize=`aws --profile AWS_TARGET  s3api list-objects --bucket ${AWS_BUCKET_TARGET} --prefix "$TargetObject" --query 'Contents[*].{Size: Size}' --output text`
#                       if [[ $SourceFileSize == $TargetFileSize ]] ; then
                                aws --profile AWS_SQS --region us-west-2 sqs delete-message --queue-url "${SQS_URL}" --receipt-handle "$ReceiptHandle"
#                       fi
                else
                        break 2
                fi
        done < <(aws --profile AWS_SQS --region us-west-2 sqs receive-message --queue-url "${SQS_URL}" --max-number-of-messages 10 --query 'Messages[*].{Body: Body, ReceiptHandle: ReceiptHandle}'  --output text)

done

#aws --profile AWS_SQS --region us-west-2 sqs delete-message --queue-url "${SQS_URL}" --receipt-handle
