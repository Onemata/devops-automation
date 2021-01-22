#!/bin/bash

# Set GLOBAL Variables for configuration files and output file
AWS_PROFILES_CONF=./aws_profiles.conf
AWS_TAGS_CONF=./aws_required_tags.conf
MISSING_TAGS_FILE=./aws_instances_missing_tags.csv

# Read in the conf files into an array
while read line ; do arrayTagsList[c++]="$line" ; done < <(cat ${AWS_TAGS_CONF})
while read line ; do arrayProfiles[c++]="$line" ; done < <(cat ${AWS_PROFILES_CONF})

# Empty the file used for tracking which instances are missing required tags
cat /dev/null > ${MISSING_TAGS_FILE}


# Set variables for running commands in AWS.
# Not the use of \$ in front of variables to delay evaluating variables
cmdBaseAWS="aws --output text --profile \$profile --region \$region" 
cmdGetRegions="$cmdBaseAWS --query 'regions[*].[name]' lightsail get-regions"
cmdGetInstances="$cmdBaseAWS --query 'Reservations[*].Instances[*].[InstanceId]' \
               ec2 describe-instances"
cmdGetInstnaceTags="$cmdBaseAWS --query 'Reservations[*].Instances[*].[Tags]' \
               ec2 describe-instances --instance-ids \$instanceId"
cmdGetInstnaceVolumes="$cmdBaseAWS --query 'Reservations[*].Instances[*].BlockDeviceMappings[*].[*.VolumeId]' \
               ec2 describe-instances --instance-ids \$instanceId"
cmdGetInstnaceNetworkInterfaces="$cmdBaseAWS --query 'Reservations[*].Instances[*].NetworkInterfaces[*].[NetworkInterfaceId]' \
               ec2 describe-instances --instance-ids \$instanceId"
cmdGetOwnerId="$cmdBaseAWS --query 'Reservations[*].[OwnerId]' \
		       ec2 describe-instances --instance-ids \$instanceId"
                  
fUpdateInstanceTags () {
   profile=$1
   region=$2
   instanceId=$3
   unset arrayTags
   unset arrayApplyTags
   unset arrayVolumeIds
   unset arrayNetworkIds
   
   ownerId=`eval ${cmdGetOwnerId}`

   while read tagKey tagValue; do
	   arrayTags[c++]="$tagKey"
	   arrayApplyTags[c++]=Key=$tagKey,Value=\"$tagValue\"
#	   echo "${arrayApplyTags[*]}"
#	   echo "${arrayTags[*]}"
   done < <(eval ${cmdGetInstnaceTags})

   # Loop through the list of required tags to make sure all tags are present on the instance
   for tagRequired in ${arrayTagsList[*]} ; do
        tagFound=false
	for tagExisting in ${arrayTags[*]} ; do
            if [[ "$tagRequired" == "$tagExisting" ]] ; then
               tagFound=true
	       return
            else
               tagFound=false
            fi
	done
	if [[ $tagFound == "false" ]] ; then
            echo "$ownerId,$region,$instanceId,$tagRequired" >> ${MISSING_TAGS_FILE}
	fi
   done

   while read volumeId ; do
	   arrayVolumeIds[c++]="$volumeId"
   done < <(eval ${cmdGetInstnaceVolumes})

   while read networkId ; do
	   arrayNetworkIds[c++]="$networkId"
   done < <(eval ${cmdGetInstnaceNetworkInterfaces})
#   set -x
   aws --profile $profile --region ${region} ec2 create-tags --resources ${arrayVolumeIds[*]} ${arrayNetworkIds[*]} --tags ${arrayApplyTags[*]}
#   set -

}

# Loop through each profile (AWS Account)
for profile in ${arrayProfiles[*]} ; do
    # Get list of regions
    # Set a default region for this command to get the list of all regions
    region=us-east-1
    while read region; do arrayRegions[c++]="$region" ; done < <(eval ${cmdGetRegions})
    # Loop through each region looking for EC2 instances
    for region in ${arrayRegions[*]} ; do
        #eval echo ${cmdGetInstances}
        while read instance; do
            # Call function to scan for instances and update tags
            fUpdateInstanceTags $profile $region $instance
        done < <(eval ${cmdGetInstances})
    done
done
  


