#!/bin/bash


# Set GLOBAL Variables for configuration files and output file
AWS_PROFILES_CONF=./aws_profiles.conf

AWS_PROFILE="onemata-automation-Feeds"

CSV_FILE=./aws_s3_bucket_report.csv
> $CSV_FILE

# Read in the conf files into an array
while read line ; do arrayProfiles[c++]="$line" ; done < <(cat ${AWS_PROFILES_CONF})

echo -e "Account\tBucket Name\tCreation Date\tLast Modified\tLocation\tSize\tSize Readable\tObjects\tIs Public\tIgnore Public ACLS\tBlock Public Policy\tBlock Public ACLS\tRestrict Public Buckets\tLifecycle Policy" > $CSV_FILE

fGenerateBucketReport () {
    AWS_PROFILE=$1
    awsAccount=`aws --profile ${AWS_PROFILE} sts get-caller-identity --query Account --output text`

    while read awsBucketCreationDate awsBucket other
    do
    #	echo "====================================================="
    #	echo "Bucket Name:  ${awsBucket}"
    #	echo "Created:      ${awsBucketCreationDate}"

        awsBucketLocation=`aws --profile ${AWS_PROFILE} s3api get-bucket-location --bucket ${awsBucket} --output text`
        if [[ ${awsBucketLocation} == 'null' ]] ; then awsBucketLocation='us-east-1' ; fi
        awsBucketLifecyclePolicy=`aws --profile ${AWS_PROFILE}  s3api get-bucket-lifecycle-configuration  --bucket ${awsBucket} 2> /dev/null | jq . -c`
        awsBucketIsPublic=`aws --profile ${AWS_PROFILE}  s3api get-bucket-policy-status --query PolicyStatus --bucket ${awsBucket} --output text 2> /dev/null`
        awsBucketIsPublic=${awsBucketIsPublic:="False"}
        read awsIgnorePublicAcls awsBlockPublicPolicy awsBlockPublicAcls awsRestrictPublicBuckets < <(aws --profile ${AWS_PROFILE} s3api get-public-access-block --bucket ${awsBucket} --query PublicAccessBlockConfiguration --output text 2> /dev/null)
        read awsBucketLastModified < <(aws --profile ${AWS_PROFILE} s3api list-objects-v2 --bucket ${awsBucket} --query 'sort_by(Contents, &LastModified)[-1].LastModified' --output=text 2> /dev/null)
        awsBucketSize=0
        awsBucketObjects=0
        unset awsBucketSizeReadable
        while read size number other
        do
            awsBucketSize=$((awsBucketSize+size))
            awsBucketObjects=$((awsBucketObjects+number))
        done < <(aws --profile ${AWS_PROFILE} s3api list-objects --bucket ${awsBucket} --query "[sum(Contents[].Size), length(Contents[])]" --output text 2>/dev/null)

        if [[ ${awsBucketSize} -gt 1099511627776 ]] ; then
            awsBucketSizeReadable=`perl -e "printf('%.2f', ${awsBucketSize}/1099511627776)"`" TB"
        elif [[ ${awsBucketSize} -gt 1073741824 ]] ; then
            awsBucketSizeReadable=`perl -e "printf('%.2f', ${awsBucketSize}/1073741824)"`" GB"
        elif [[ ${awsBucketSize} -gt 1048576 ]] ; then
            awsBucketSizeReadable=`perl -e "printf('%.2f', ${awsBucketSize}/1048576)"`" MB"
        elif [[ ${awsBucketSize} -gt 1024 ]] ; then
            awsBucketSizeReadable=`perl -e "printf('%.2f', ${awsBucketSize}/1024)"`" KB"
        fi

        echo -e "${awsAccount}\t${awsBucket}\t${awsBucketCreationDate}\t${awsBucketLastModified}\t${awsBucketLocation}\t${awsBucketSize}\t${awsBucketSizeReadable}\t${awsBucketObjects}\t${awsBucketIsPublic}\t${awsIgnorePublicAcls}\t${awsBlockPublicPolicy}\t${awsBlockPublicAcls}\t${awsRestrictPublicBuckets}"
        echo -e "${awsAccount}\t${awsBucket}\t${awsBucketCreationDate}\t${awsBucketLastModified}\t${awsBucketLocation}\t${awsBucketSize}\t${awsBucketSizeReadable}\t${awsBucketObjects}\t${awsBucketIsPublic}\t${awsIgnorePublicAcls}\t${awsBlockPublicPolicy}\t${awsBlockPublicAcls}\t${awsRestrictPublicBuckets}\t${awsBucketLifecyclePolicy}" >> $CSV_FILE

    done < <(aws --profile ${AWS_PROFILE} s3api list-buckets --query 'Buckets[*].{"Name": Name, "CreationDate": CreationDate}' --output text)
}

# Loop through each profile (AWS Account)
for profile in ${arrayProfiles[*]} ; do
    echo "Starting profile: $profile"
    # Call function to generate bucket report for specified profile
    fGenerateBucketReport $profile
done
