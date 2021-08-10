#!/bin/bash


# Include common functions
source ./processFeedsFunctions.sh

# Validate variables
fValidateEnvironmentVariables

# Write/Add Credentials
fAddCredentials

set -x
# Make sure we can access SQS Queue
fValidateAccessToSQSQueue
RC=$?

if [[ $RC -ne 0 ]] ; then
    echo "ERROR:  Unable to access SQS Queue [${SQS_URL}]"
    echo "Exiting...."
    exit 1
fi

# Make sure we can access the source bucket
fValidateAccessToSourceBucket
RC=$?

if [[ $RC -ne 0 ]] ; then
    echo "ERROR:  Unable to access source bucket [${AWS_BUCKET_SOURCE}]"
    echo "Exiting...."
    exit 1
fi

# Make sure we can access the target bucket
fValidateAccessToTargetBucket
RC=$?

if [[ $RC -ne 0 ]] ; then
    echo "ERROR:  Unable to access target bucket [${TARGET_BUCKET}]"
    echo "Exiting...."
    exit 1
fi

while [[ 0 -eq 0 ]]
do
    while read MessageBody ReceiptHandle Other
    do
        sourceObject="${MessageBody}"

        targetPrefix=`fTransformTargetPrefix "${sourceObject}" "${PREFIX_TEMPLATE}"`
        object=`fTransformTargetObject "${sourceObject}" "${OBJECT_TEMPLATE}"`

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

    done < <(fFetchMessageFromQueue)


done


# Copy

fValidateTargetObject
