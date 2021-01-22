#!/bin/bash


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
   cmdGetInstnaceVolumes="aws  --query 'Reservations[*].Instances[*].BlockDeviceMappings[*].[*.VolumeId]' --output=text  --profile $profile --region ${region} ec2 describe-instances --instance-ids $instanceId"
#   cmdGetInstnaceVolumes="aws  --query 'Reservations[*].Instances[*].[BlockDeviceMappings]' --output=json  --profile $profile --region ${region} ec2 describe-instances --instance-ids $instanceId"
   cmdGetInstnaceNetworkInterfaces="aws --output=text --profile $profile --region ${region} \
	               --query 'Reservations[*].Instances[*].NetworkInterfaces[*].[NetworkInterfaceId]' \
                       ec2 describe-instances --instance-ids $instanceId"

   while read tagKey tagValue; do
	   arrayTags[c++]="$tagKey"
	   arrayApplyTags[c++]=Key=$tagKey,Value=\"$tagValue\"
#	   echo "${arrayApplyTags[*]}"
#	   echo "${arrayTags[*]}"
   done < <(eval ${cmdGetInstnaceTags})

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
