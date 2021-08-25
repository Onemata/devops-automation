#!/bin/bash

#==============================================================================
#-  Function:  fValidateEnvironmentVariables
#-
#==============================================================================
fValidateEnvironmentVariables () {
    case "${TARGET_PLATFORM}" in
        "")     echo "No Target Platform specified.  Exiting."; exit 1 ;;
        google) echo "Target Platform:  ${TARGET_PLATFORM}"; fValidateEnvironmentVariablesForGooglePlatform ;;
        aws)    echo "Target Platform:  ${TARGET_PLATFORM}"; fValidateEnvironmentVariablesForAWSPlatform ;;
        azure)  echo "Target Platform:  ${TARGET_PLATFORM}"; fValidateEnvironmentVariablesForAzurePlatform ;;
        *)      echo "Unknown Target Platform specified:  ${TARGET_PLATFORM}.  Exiting."; exit 1 ;;
    esac

    fValidateEnvironmentVariablesCommon
}

#==============================================================================
#-  Function:  fValidateEnvironmentVariablesCommon
#-
#==============================================================================
fValidateEnvironmentVariablesCommon () {
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
    if [[ -z "${SQS_URL}" ]] ; then
        echo "Please set SQS_URL for location of SQS"
        exit 1
    fi
    if [[ -z "${AWS_BUCKET_SOURCE}" ]] ; then
        echo "Please set AWS_BUCKET_SOURCE for location of source bucket"
        exit 1
    fi
    if [[ -z "${TARGET_BUCKET}" ]] ; then
        echo "Please set TARGET_BUCKET for location of target bucket"
        exit 1
    fi

}

#==============================================================================
#-  Function:  fValidateEnvironmentVariablesForAzurePlatform
#-
#==============================================================================
fValidateEnvironmentVariablesForAzurePlatform () {
    if [[ -z "${AZ_USERNAME}" ]] ; then
        echo "Please set AZ_USERNAME"
        exit 1
    fi
    if [[ -z "${AZ_PASSWORD}" ]] ; then
        echo "Please set AZ_PASSWORD"
        exit 1
    fi
    if [[ -z "${AZ_ACCOUNT_NAME}" ]] ; then
        echo "Please set AZ_ACCOUNT_NAME"
        exit 1
    fi
    #Setup pyenv
    pip install blobxfer
}

#==============================================================================
#-  Function:  fValidateEnvironmentVariablesForGooglePlatform
#-
#==============================================================================
fValidateEnvironmentVariablesForGooglePlatform () {
    if [[ -z "${GS_PROJECT_ID}" ]] ; then
        echo "Please set GS_PROJECT_ID"
        exit 1
    fi
    if [[ -z "${GS_PRIVATE_KEY_ID}" ]] ; then
        echo "Please set GS_PRIVATE_KEY_ID"
        exit 1
    fi
    if [[ -z "${GS_PRIVATE_KEY}" ]] ; then
        echo "Please set GS_PRIVATE_KEY"
        exit 1
    fi
    if [[ -z "${GS_CLIENT_EMAIL}" ]] ; then
        echo "Please set GS_CLIENT_EMAIL"
        exit 1
    fi
    if [[ -z "${GS_CLIENT_ID}" ]] ; then
        echo "Please set GS_CLIENT_ID"
        exit 1
    fi
    if [[ -z "${GS_CLIENT_CERT}" ]] ; then
        echo "Please set GS_CLIENT_CERT"
        exit 1
    fi
}

#==============================================================================
#-  Function:  fValidateEnvironmentVariablesForAWSPlatform
#-
#==============================================================================
fValidateEnvironmentVariablesForAWSPlatform () {
    if [[ -z "${SECRET_KEY_TARGET}" ]] ; then
        echo "Please set SECRET_KEY_TARGET"
        exit 1
    fi
    if [[ -z "${ACCESS_KEY_TARGET}" ]] ; then
        echo "Please set ACCESS_KEY_TARGET"
        exit 1
    fi
}

#==============================================================================
#-  Function:  fAddCredentials
#-
#==============================================================================
fAddCredentials () {
    fAddAWSCredentials
    if [[ "${TARGET_PLATFORM}" == "google" ]] ; then
        fAddGoogleCredentials
    elif [[ "${TARGET_PLATFORM}" == "azure" ]] ; then
        fAddAzureCredentials
    fi
}

#==============================================================================
#-  Function:  fAddAzureCredentials
#-
#==============================================================================
fAddAzureCredentials () {
    # Do login action to create accessTokens.json
    az login -u "${AZ_USERNAME}" -p "${AZ_PASSWORD}"
    RC=$?
    if [[ $RC -ne 0 ]] ; then
        echo "Login to Azure not successful.  Exiting..."
        exit 1
    fi
}
#==============================================================================
#-  Function:  fAddAWSCredentials
#-
#==============================================================================
fAddAWSCredentials () {

    awsCredFile=~/.aws/credentials
    mkdir -vp ~/.aws
    touch ${awsCredFile}
    chmod -R 600 ~/.aws

    echo "[AWS_SQS]" >> ${awsCredFile}
    echo "aws_secret_access_key = ${SECRET_KEY_SQS}"  >> ${awsCredFile}
    echo "aws_access_key_id = ${ACCESS_KEY_SQS}" >> ${awsCredFile}
    echo "[AWS_SOURCE]" >> ${awsCredFile}
    echo "aws_secret_access_key = ${SECRET_KEY_SOURCE}"  >> ${awsCredFile}
    echo "aws_access_key_id = ${ACCESS_KEY_SOURCE}" >> ${awsCredFile}
    if [[ "${TARGET_PLATFORM}" == "aws" ]] ; then
        echo "[AWS_TARGET]" >> ${awsCredFile}
        echo "aws_secret_access_key = ${SECRET_KEY_TARGET}"  >> ${awsCredFile}
        echo "aws_access_key_id = ${ACCESS_KEY_TARGET}" >> ${awsCredFile}
    fi
}

#==============================================================================
#-  Function:  fAddGoogleCredentials
#-
#==============================================================================
fAddGoogleCredentials () {

    gsServiceKeyFile=~/onemata.json

    cp -v ./.boto ~/.boto
    cp -v ./onemata.json ${gsServiceKeyFile}
    chmod -R 600 ~/.boto ${gsServiceKeyFile}

    # Update the .boto file with the location of the onemata.json file
    sed -i "s|__GS_SERVICE_KEY_FILE__|${gsServiceKeyFile}|" ~/.boto

    # Update the json file with the access keys and secret keys
    sed -i "s|__PROJECT_ID__|${GS_PROJECT_ID}|" ${gsServiceKeyFile}
    sed -i "s|__PRIVATE_KEY_ID__|${GS_PRIVATE_KEY_ID}|" ${gsServiceKeyFile}
    sed -i "s|__PRIVATE_KEY__|${GS_PRIVATE_KEY}|" ${gsServiceKeyFile}
    sed -i "s|__CLIENT_EMAIL__|${GS_CLIENT_EMAIL}|" ${gsServiceKeyFile}
    sed -i "s|__CLIENT_ID__|${GS_CLIENT_ID}|" ${gsServiceKeyFile}
    sed -i "s|__CLIENT_CERT__|${GS_CLIENT_CERT}|" ${gsServiceKeyFile}
}

#==============================================================================
#-  Function:
#-
#==============================================================================
fValidateAccessToSQSQueue () {
    queue_url=$1

    # Test access to the SQS Queue
    echo "Validating Access to ${queue_url}"
    aws --profile AWS_SQS --region ${AWS_REGION} sqs get-queue-attributes --queue-url "${queue_url}" --attribute-names ApproximateNumberOfMessages --output text
    return $?
}

#==============================================================================
#-  Function:
#-
#==============================================================================
fValidateAccessToSourceBucket () {
    bucket=$1
    # Test access to Source S3 Location
    return 0
    echo "Validating Access to source bucket: ${bucket}"
    aws --profile AWS_SOURCE s3 ls s3://${bucket} --output text
    return $?
}

#==============================================================================
#-  Function:
#-
#==============================================================================
fValidateAccessToTargetBucket () {
    bucket=$1

    if [[ "${TARGET_PLATFORM}" == "aws" ]] ; then
        echo "Validating Access to target AWS bucket: ${bucket}"
        aws --profile AWS_TARGET s3 ls s3://${bucket} --output text
        return_code=$?
    elif [[ "${TARGET_PLATFORM}" == "google" ]] ; then
        echo "Validating Access to target Google bucket: ${bucket}"
        gsutil ls -l gs://${bucket}/
        return_code=$?
    elif [[ "${TARGET_PLATFORM}" == "azure" ]] ; then
        echo "Validating Access to target Azure bucket: ${bucket} for account: ${AZ_ACCOUNT_NAME}"
        ####  Cli for Azure
        az storage blob list --account-name ${AZ_ACCOUNT_NAME} --container-name ${bucket} --output table --auth-mode login
        return_code=$?
    fi
    return $return_code
}

#==============================================================================
#-  Function:
#-
#==============================================================================
fValidateTargetObject () {
    source=$1
    target=$2

    sourceObjectSize=`aws --profile AWS_SOURCE  s3api list-objects --bucket ${AWS_BUCKET_SOURCE} --prefix "$source" --query 'Contents[*].{Size: Size}' --output text`

    if [[ "${TARGET_PLATFORM}" == "aws" ]] ; then
        targetObjectSize=`aws --profile AWS_TARGET  s3api list-objects --bucket ${TARGET_BUCKET} --prefix "$target" --query 'Contents[*].{Size: Size}' --output text`

    elif [[ "${TARGET_PLATFORM}" == "google" ]] ; then
        read targetObjectSize date object < <(gsutil ls -l gs://${TARGET_BUCKET}/$target)
    elif
        targetObjectSize=`az storage blob list --account-name ${AZ_ACCOUNT_NAME} --container-name ${TARGET_BUCKET} --output tsv --auth-mode login --prefix "$target" --query "[*].[properties.contentLength]"`
    fi

    if [[ $sourceObjectSize -eq $targetObjectSize ]] ; then
        return 0
    else
        echo "ERROR:  Source object size: $sourceObjectSize / Target object size: $targetObjectSize"
        return 1
    fi
}

#==============================================================================
#-  Function:
#-
#==============================================================================
fTransformTargetPrefix () {
    # Use the following format:
    #  {year} for year
    #  {month} for month
    #  {day} for day

    sourceObject=$1
    targetPrefixFormat=$2

    #object=${sourceObject##*/}
    prefix=${sourceObject%/*}
    if [[ "${targetPrefixFormat}" == "" ]] ; then
        echo "${prefix}"
        return 0
    fi

    year=`grep -o "output_year=...." <<< $prefix` ; year=${year#*=}
    month=`grep -o "output_month=.." <<< $prefix` ; month=${month#*=}
    day=`grep -o "output_day=.." <<< $prefix` ; day=${day#*=}
    country=`grep -o "location_country=.." <<< $prefix` ; country=${country#*=}

    newPrefix="${targetPrefixFormat/\{year\}/${year}}"
    newPrefix="${newPrefix/\{month\}/${month}}"
    newPrefix="${newPrefix/\{day\}/${day}}"
    newPrefix="${newPrefix/\{country\}/${country}}"

    echo "${newPrefix}"
    return 0
}

#==============================================================================
#-  Function:
#-
#==============================================================================
fTransformTargetObject () {

    sourceObject=$1
    #echo "Function:  $0: not used yet"

    object=${sourceObject##*/}
    echo "${object}"
}

#==============================================================================
#-  Function:
#-
#==============================================================================
fFetchMessageFromQueue () {
    #echo "Fetching 10 messages at a time"
    aws --profile AWS_SQS --region ${AWS_REGION} sqs receive-message --queue-url "${SQS_URL}" --max-number-of-messages 10 --query 'Messages[*].{Body: Body, ReceiptHandle: ReceiptHandle}'  --output text

}

#==============================================================================
#-  Function:  fCopyObject
#-
#==============================================================================
fCopyObject () {

    source=$1
    target=$2

    if [[ "${TARGET_PLATFORM}" == "aws" ]] ; then
        echo "Copying object to AWS S3 Bucket"
        aws --profile AWS_SOURCE s3 cp s3://${AWS_BUCKET_SOURCE}/$source - | aws --profile AWS_TARGET s3 cp --acl bucket-owner-full-control - s3://${TARGET_BUCKET}/$target
    elif [[ "${TARGET_PLATFORM}" == "google" ]] ; then
        echo "Copying object to Google Bucket"
        aws --profile AWS_SOURCE s3 cp s3://${AWS_BUCKET_SOURCE}/$source - | gsutil cp - gs://${TARGET_BUCKET}/$target
    elif [[ "${TARGET_PLATFORM}" == "azure" ]] ; then
        echo "Copying object to Azure Bucket"
        aws --profile AWS_SOURCE s3 cp s3://${AWS_BUCKET_SOURCE}/$source - | az storage blob upload --account-name ${AZ_ACCOUNT_NAME} --file - --container-name ${TARGET_BUCKET} --name $target --auth-mode login
    fi
}

#==============================================================================
#-  Function:
#-
#==============================================================================
fDeleteMessageFromQueue () {
    handle=$1
    aws --profile AWS_SQS --region ${AWS_REGION} sqs delete-message --queue-url "${SQS_URL}" --receipt-handle "$handle"

}



