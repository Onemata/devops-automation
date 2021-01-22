#!/bin/bash

AWS_PROFILES_CONF=./aws_profiles.conf
AWS_TAGS_CONF=./aws_required_tags.conf
MISSING_TAGS_FILE=./aws_instances_missing_tags.csv

echo > ${MISSING_TAGS_FILE}
while read line ; do arrayTagsList[c++]="$line" ; done < <(cat ${AWS_TAGS_CONF})
while read line ; do arrayAWSProfiles[c++]="$line" ; done < <(cat ${AWS_PROFILES_CONF})


profile=onemata-automation-AutomatedDataManagement

cmdBaseAWS="aws --output=text"
cmdGetRegions="aws --output=text --query 'regions[*].[name]' --profile $profile lightsail get-regions"

cmdGetInstances="aws  --output=text --query 'Reservations[*].Instances[*].[InstanceId]'  --profile $profile --region \${region} ec2 describe-instances"

fUpdateInstanceTags () {
   profile=$1
   region=$2
   instanceId=$3
   unset arrayTags
   unset arrayApplyTags
   unset arrayVolumeIds
   unset arrayNetworkIds
   cmdGetInstnaceTags="aws  --query 'Reservations[*].Instances[*].[Tags]' --output=text  --profile $profile --region ${region} ec2 describe-instances --instance-ids $instanceId"
   cmdGetInstnaceVolumes="aws --output=text --profile $profile --region ${region} \
	               --query 'Reservations[*].Instances[*].BlockDeviceMappings[*].[*.VolumeId]' \
		       ec2 describe-instances --instance-ids $instanceId"
   cmdGetInstnaceNetworkInterfaces="aws --output=text --profile $profile --region ${region} \
	               --query 'Reservations[*].Instances[*].NetworkInterfaces[*].[NetworkInterfaceId]' \
                       ec2 describe-instances --instance-ids $instanceId"
   cmdGetOwnerId="aws --output=text --profile $profile --region ${region} \
	               --query 'Reservations[*].[OwnerId]' \
		       ec2 describe-instances --instance-ids $instanceId"

   ownerId=`eval $cmdGetOwnerId`

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

while read region; do
   arrayRegions[c++]="$region"
done < <(eval ${cmdGetRegions})

for region in ${arrayRegions[*]} ; do
   echo $region
   #eval echo ${cmdGetInstances}
   while read instance; do
      arrayInstances[c++]="$instance"
      fUpdateInstanceTags $profile $region $instance
#      echo ${arrayInstances[*]}
   done < <(eval ${cmdGetInstances})
#   eval ${cmdGetInstances}
done
