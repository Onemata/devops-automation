#!/bin/bash
source ~/.bashrc
set -x

S3_OBJECTS_TO_ADD_TO_SQS=./s3_objects_to_copy.txt
> ${S3_OBJECTS_TO_ADD_TO_SQS}

awsBucketSource=${AWS_BUCKET_SOURCE}
awsProfileSource=${AWS_PROFILE_SOURCE}
awsBasePrefixSource=${AWS_BASE_PREFIX_SOURCE}
bambooWorkingDir=${WORKING_DIR}
YEAR=
maxNumberOfTasks=10

#profile=$1
#awsBucket=$2
#YEAR=$4
#MONTH=$5


#export MONTH=07

#export OUTPUT_YEAR=`date --date="$bamboo_OUT_DATE_STR" +%Y`
#export OUTPUT_MONTH=`date --date="$bamboo_OUT_DATE_STR" +%m`
#export OUTPUT_DAY=`date --date="$bamboo_OUT_DATE_STR" +%d`


unset arrayOfFiles
unset numFileCount
unset numTotalFileCount
unset numTotalSize
unset numTotalSizeOfAllFiles
unset arrayEntry
numOfTasks=1
while read prefix ; do
    basePrefix=$prefix
    basePrefix="${prefix}output_year=2021/output_month=06"
    while read file size ; do
        if [[ $size -gt 999 ]] ; then
            # File is greater than 1K, so add to arrary
            arrayOfFiles[c++]=$file
        ((numFileCount+=1))
        ((numTotalFileCount+=1))
        numTotalSize=$((numTotalSize+size))
        numTotalSizeOfAllFiles=$((numTotalSizeOfAllFiles+size))
        if [[ $numTotalSize -gt 1099511627776 ]] ; then
            arrayEntry[c++]="$numTotalSize,$numFileCount"
            unset numTotalSize
            unset numFileCount
                if [[ $numOfTasks -lt $maxNumberOfTasks ]] ; then
               ((numOfTasks+=1))
            fi
            fi
        fi
 #   done < <(aws --profile ${awsProfileSource} s3api list-objects --bucket ${awsBucketSource} --prefix "$prefix" --query "Contents[?contains(Key, '_20210')].[Key,Size]" --output text)
    done < <(aws --profile ${awsProfileSource} s3api list-objects --bucket ${awsBucketSource} --prefix "$basePrefix" --query "Contents[].[Key,Size]" --output text)

#done < <(aws --profile $profile s3api list-objects --bucket ${awsBucket} --prefix "spark-results/14206-us2/year=$YEAR/date=$YEAR-$MONTH" --query 'CommonPrefixes' --delimiter '/' --output text)
#done < <(aws --profile ${awsProfileSource} s3api list-objects --bucket ${awsBucketSource} --prefix "${awsBasePrefixSource}" --query 'CommonPrefixes' --delimiter '/' --output text)
#--query "Contents[?contains(Key, '202105')].[Key,Size]"
done < <(aws --profile ${awsProfileSource} s3api list-objects --bucket ${awsBucketSource} --prefix "${awsBasePrefixSource}" --query 'CommonPrefixes' --delimiter '/' --output text)
#done < <(aws --profile ${awsProfileSource} s3api list-objects --bucket ${awsBucketSource} --prefix "location_country" --query 'CommonPrefixes' --delimiter '/' --output text)

        if [[ ${numTotalSizeOfAllFiles} -gt 1099511627776 ]] ; then
            numTotalSizeReadable=`perl -e "printf('%.2f', ${numTotalSizeOfAllFiles}/1099511627776)"`" TB"
        elif [[ ${numTotalSizeOfAllFiles} -gt 1073741824 ]] ; then
            numTotalSizeReadable=`perl -e "printf('%.2f', ${numTotalSizeOfAllFiles}/1073741824)"`" GB"
        elif [[ ${numTotalSizeOfAllFiles} -gt 1048576 ]] ; then
            numTotalSizeReadable=`perl -e "printf('%.2f', ${numTotalSizeOfAllFiles}/1048576)"`" MB"
        elif [[ ${numTotalSizeOfAllFiles} -gt 1024 ]] ; then
            numTotalSizeReadable=`perl -e "printf('%.2f', ${numTotalSizeOfAllFiles}/1024)"`" KB"
        fi

echo " "
echo "=================================================="
echo "Total File Count: $numTotalFileCount"
echo "Total File Size:  $numTotalSizeOfAllFiles Bytes"
echo "Total File Size:  ${numTotalSizeReadable}"
echo "Number of Tasks:  ${numOfTasks}"
echo "=================================================="
echo " "

echo "NUM_OF_TASKS=${numOfTasks}" > ${bambooWorkingDir}/env.properties
echo "NUM_OF_TASKS=10" > ${bambooWorkingDir}/env.properties

echo "Sending Messages to SQS"
#  Batch up to 10 messages together
SQS_URL="https://sqs.us-west-2.amazonaws.com/620889225884/copy_feeds"
AWS_PROFILE_FEEDS=onemata-automation-Feeds
#BASE_MESSAGE_ENTRY="--entries "Id=1,MessageBody=string1,MessageGroupId=bamboo,MessageDeduplicationId=bamboo" "Id=2,MessageBody=string2,MessageGroupId=bamboo,MessageDeduplicationId=bamboo"
#set -x
count=0
unset arrayOfEntries
index=0
for entry in ${arrayOfFiles[@]} ; do
        #BATCH_ENTRY="Id=$count,MessageBody=$entry,MessageGroupId=bamboo,MessageDeduplicationId=bamboo"
        BATCH_ENTRY="Id=$count,MessageBody=$entry"
        if [[ $count -lt 10 ]] ; then
              arrayOfEntries[index]="${arrayOfEntries[$index]} ${BATCH_ENTRY}"
#	aws --profile ${AWS_PROFILE_FEEDS} --region us-west-2 sqs send-message --queue-url "${SQS_URL}" --message-body "${entry}" --message-group-id "bamboo" --message-deduplication-id "bamboo"
#	aws --profile ${AWS_PROFILE_FEEDS} --region us-west-2 sqs send-message-batch --queue-url "${SQS_URL}" --message-body "${entry}" --message-group-id "bamboo" --message-deduplication-id "bamboo"
#              echo $index
     elif [[ $count -eq 10 ]] ; then
         count=0
         arrayOfEntries[++index]="${BATCH_ENTRY}"
     fi
     ((count+=1))
done
#set -x


for ix in ${!arrayOfEntries[*]} ; do
#	echo "${arrayOfEntries[$ix]}"
    echo "${arrayOfEntries[$ix]}" >> ${S3_OBJECTS_TO_ADD_TO_SQS}
#	echo "--------------------------------"
#	aws --profile ${AWS_PROFILE_FEEDS} --region us-west-2 sqs send-message-batch --queue-url "${SQS_URL}" --entries ${arrayOfEntries[$ix]}

done

exit

echo " "
echo "=================================================="
echo "Total File Count: $numTotalFileCount"
echo "Total File Size:  $numTotalSizeOfAllFiles Bytes"
echo "Total File Size:  ${numTotalSizeReadable}"
echo "Number of Tasks:  ${numOfTasks}"
echo "=================================================="
echo " "

exit
