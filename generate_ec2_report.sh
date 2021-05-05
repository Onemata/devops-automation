#!/bin/bash
#set -x

# Set GLOBAL Variables for configuration files and output file
AWS_PROFILES_CONF=./aws_profiles.conf
AWS_TAGS_CONF=./aws_required_tags.conf
MISSING_TAGS_FILE=./aws_instances_missing_tags.csv
AWS_EC2_LIST=./aws_ec2_resource_list.csv

# Read in the conf files into an array
#while read line ; do arrayTagsList[c++]="$line" ; done < <(cat ${AWS_TAGS_CONF})
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

cmdGetInstanceDetails="$cmdBaseAWS --query 'Reservations[*].Instances[*].[Tags[?Key==\`Name\`]|[0].Value,InstanceId,InstanceType,State.Name,KeyName,Platform,LaunchTime,PrivateIpAddress,PublicIpAddress,SubnetId,VpcId,Placement.AvailabilityZone,Architecture,Hypervisor,VirtualizationType]' \
               ec2 describe-instances --instance-ids \$instanceId"
cmdGetInstanceState="$cmdBaseAWS --query 'Reservations[*].Instances[*].State[*].Name' \
               ec2 describe-instances --instance-ids \$instanceId"
cmdGetInstanceZone="$cmdBaseAWS --query 'Reservations[*].Instances[*].Placement[*].AvailabilityZone' \
               ec2 describe-instances --instance-ids \$instanceId"

fUpdateInstanceTags () {
   profile=$1
   region=$2
   instanceId=$3
   unset arrayTags
   unset arrayApplyTags
   unset arrayVolumeIds
   unset arrayNetworkIds
   unset arrayResourceIds

   ownerId=`eval ${cmdGetOwnerId}`
   eval echo "=========================================================================="
   echo "----- Account: $ownerId - $region - Instance: $instanceId "

   while IFS=$'\t' read -r tagKey tagValue; do
       # Check to see if the tagKey is an AWS reserved key and ignore those
#       echo "Found Tag: $tagKey"
       if [[ $tagKey == "None" ]]; then
           echo "This instance has no tags"
       elif [[ $tagKey =~ ^aws: ]]; then
           echo "Reserved Tag: $tagKey"
       else
           echo "Valid Tag:    $tagKey"
           arrayTags[c++]="$tagKey"
           arrayApplyTags[c++]=\'Key=\"$tagKey\",Value=\"$tagValue\"\'
#           echo "${arrayApplyTags[*]}"
#           echo "${arrayTags[*]}"
       fi
   done < <(eval ${cmdGetInstnaceTags})

   if [ ${#arrayApplyTags[@]} -gt 0 ]; then
       echo "Tags: ${arrayApplyTags[*]}"
   fi

   # Loop through the list of required tags to make sure all tags are present on the instance

   for tagRequired in ${arrayTagsList[*]} ; do
       tagFound=false
       for tagFound in ${arrayTags[*]} ; do
           if [[ "$tagRequired" == "$tagFound" ]] ; then
               tagFound=true
               break
           else
               tagFound=false
           fi
       done
       if [[ $tagFound == "false" ]] ; then
           echo "'$ownerId',$region,$instanceId,$tagRequired" >> ${MISSING_TAGS_FILE}
           echo "Missing required tag: $tagRequired"
       fi
   done

   while read volumeId ; do
       arrayResourceIds[c++]="$volumeId"
   done < <(eval ${cmdGetInstnaceVolumes})

   while read networkId ; do
       arrayResourceIds[c++]="$networkId"
   done < <(eval ${cmdGetInstnaceNetworkInterfaces})

#   if [ ${#arrayVolumeIds[@]} -ne 0 ]; then
#       arrayResourceIds=("${arrayVolumeIds[@]}")
#   fi
#

   #----------------------------------------------
   # This section can be used to remove tags
   #    To remove a tag from
   #    Instance, Volumes, and Network interfaces
   # ----------------------------------------------
   #aws --profile $profile --region ${region} ec2 delete-tags --resources $instanceId ${arrayVolumeIds[*]} ${arrayNetworkIds[*]} --tags Key=None

    if [ ${#arrayApplyTags[@]} -eq 0 ]; then
        echo "No tags to apply to resources"
    elif [ ${#arrayResourceIds[@]} -eq 0 ]; then
        echo "No resources attached to EC2 instance"
    else
        #echo "Attached resources: ${arrayResourceIds[*]}
        #echo "Tags: ${arrayApplyTags[*]}"
        cmdApplyTags="aws --profile $profile --region ${region} ec2 create-tags --resources ${arrayResourceIds[*]} --tags ${arrayApplyTags[*]}"
        echo $cmdApplyTags
        #set -x
        eval $cmdApplyTags
        returnCode=$?
        #set -
        if [[ $returnCode -ne 0 ]]; then
            exit 1
        fi

        #aws --profile $profile --region ${region} ec2 create-tags --resources ${arrayVolumeIds[*]} ${arrayNetworkIds[*]} --tags ${arrayApplyTags[*]}
    fi
}

fGetInstanceDetails () {
   profile=$1
   region=$2
   instanceId=$3
   unset arrayTags
   unset arrayApplyTags
   unset arrayVolumeIds
   unset arrayNetworkIds
   unset arrayResourceIds

   ownerId=`eval ${cmdGetOwnerId}`

   # Get Public IP, Local IP, Keypair, Instance Type, VPC ID, Subnet ID, Launch Time, State, Instance ID, Virtualization Type, AVZone, Region, NameTag
   read InstanceName InstanceId InstanceType State KeyName Platform LaunchTime PrivateIp PublicIp SubnetId VpcId Zone Architecture Hypervisor VirtualizationType  < <(eval $cmdGetInstanceDetails)
   if [[ "$Platform" == "None" ]] ; then Platform=Other ; fi
   InstanceName=${InstanceName:-"None"}
   echo "$ownerId,$InstanceName,$InstanceId,$InstanceType,$State,$KeyName,$Platform,$LaunchTime,$PrivateIp,$PublicIp,$SubnetId,$VpcId,$Zone,$Architecture,$Hypervisor,$VirtualizationType" >> ${AWS_EC2_LIST}
#   eval $cmdGetInstanceDetails
#   eval $cmdGetInstanceState
#   eval $cmdGetInstanceZone
}

echo "OwnerId,InstanceName,InstanceId,InstanceType,State,KeyName,Platform,LaunchTime,PrivateIp,PublicIp,SubnetId,VpcId,Zone,Architecture,Hypervisorr,VirtualizationType" > ${AWS_EC2_LIST}
# Loop through each profile (AWS Account)
for profile in ${arrayProfiles[*]} ; do
    echo "Starting profile: $profile"
    # Get list of regions
    # Set a default region for this command to get the list of all regions
    region=us-east-1
    while read region; do arrayRegions[c++]="$region" ; done < <(eval ${cmdGetRegions})
    # Loop through each region looking for EC2 instances
    for region in ${arrayRegions[*]} ; do
        #eval echo ${cmdGetInstances}
        while read instance; do
            # Call function to scan for instances and update tags
            fGetInstanceDetails $profile $region $instance
        done < <(eval ${cmdGetInstances})
    done
done
