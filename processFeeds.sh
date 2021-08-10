#!/bin/bash


# Include common functions
source ./processFeedsFunctions.sh

# Validate variables
fValidateEnvironmentVariables

# Write/Add Credentials
fAddCredentials

set -x
sleep 2
# Make sure we can access SQS Queue
echo "Checking access to SQS Queue"
fValidateAccessToSQSQueue
RC=$?

if [[ $RC -ne 0 ]] ; then
    echo "ERROR:  Unable to access SQS Queue [${SQS_URL}]"
    echo "Exiting...."
    exit 1
fi

sleep 2
# Make sure we can access the source bucket
echo "Checking access to source bucket"
fValidateAccessToSourceBucket
RC=$?

if [[ $RC -ne 0 ]] ; then
    echo "ERROR:  Unable to access source bucket [${AWS_BUCKET_SOURCE}]"
    echo "Exiting...."
    exit 1
fi

sleep 2
# Make sure we can access the target bucket
echo "Checking access to target bucket"
fValidateAccessToTargetBucket
RC=$?

if [[ $RC -ne 0 ]] ; then
    echo "ERROR:  Unable to access target bucket [${TARGET_BUCKET}]"
    echo "Exiting...."
    exit 1
fi

sleep 2
while [[ 0 -eq 0 ]]
do
    while read MessageBody ReceiptHandle Other
    do
        if [[ "${MessageBody}" != "None" ]] ; then

            sourceObject="${MessageBody}"

            targetPrefix=`fTransformTargetPrefix "${sourceObject}" "${TARGET_PREFIX}"`
            #object=`fTransformTargetObject "${sourceObject}" "${OBJECT_TEMPLATE}"`

            targetObject="${targetPrefix}${object}"

            # Copy Object to Target Location
            fCopyObject "${sourceObject}" "${targetObject}"

            # Validate Object in Target Location
            fValidateTargetObject "${sourceObject}" "${sourceObject}"
            RC=$?

            if [[ $RC -eq 0 ]] ; then
                # Remove Item from SQS Queue
                fDeleteMessageFromQueue "${ReceiptHandle}"
            else
                echo "ERROR: target object does not match size of source object"
            fi
        else
            echo "No more messeges in queue"
            break 2
        fi

    done < <(fFetchMessageFromQueue)


done


# Copy

fValidateTargetObject
