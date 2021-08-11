#!/bin/bash


# Include common functions
source ./processFeedsFunctions.sh

# Validate variables
fValidateEnvironmentVariables

# Write/Add Credentials
fAddCredentials

sleep 2
# Make sure we can access SQS Queue
echo "Checking access to SQS Queue"
fValidateAccessToSQSQueue "${SQS_URL}"
RC=$?

if [[ $RC -ne 0 ]] ; then
    echo "ERROR:  Unable to access SQS Queue [${SQS_URL}]"
    echo "Exiting...."
    exit 1
fi

sleep 2
# Make sure we can access the source bucket
echo "Checking access to source bucket"
fValidateAccessToSourceBucket "${AWS_BUCKET_SOURCE}"
RC=$?

if [[ $RC -ne 0 ]] ; then
    echo "ERROR:  Unable to access source bucket [${AWS_BUCKET_SOURCE}]"
    echo "Exiting...."
    exit 1
fi

sleep 2
# Make sure we can access the target bucket
echo "Checking access to target bucket"
fValidateAccessToTargetBucket "${TARGET_BUCKET}"
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
            echo "SOURCE:  ${sourceObject}"

            object=${MessageBody##*/}
            echo "OBJECT:  ${object}"

            targetPrefix=`fTransformTargetPrefix "${sourceObject}" "${TARGET_PREFIX}"`
            echo "PREFIX:  ${targetPrefix}"

            #object=`fTransformTargetObject "${sourceObject}" "${OBJECT_TEMPLATE}"`

            targetObject="${targetPrefix}/${object}"
            echo "TARGET:  ${targetObject}"

            # Copy Object to Target Location
            echo "Copying ${sourceObject} TO ${targetObject}"
            fCopyObject "${sourceObject}" "${targetObject}"

            # Validate Object in Target Location
            echo "Validating file size"
            fValidateTargetObject "${sourceObject}" "${targetObject}"
            RC=$?

            if [[ $RC -eq 0 ]] ; then
                # Remove Item from SQS Queue
                echo "Remove message from queue"
                fDeleteMessageFromQueue "${ReceiptHandle}"
            else
                echo "ERROR: target object does not match size of source object"
                exit 1
            fi

        else
            echo "No more messeges in queue"
            exit 0
            break 2
        fi

    done < <(fFetchMessageFromQueue)


done




