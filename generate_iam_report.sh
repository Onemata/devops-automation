#!/bin/bash

AWS_PROFILES_CONF=./aws_profiles.conf
SINGLE_REPORT_FILE=./aws_iam_credentials_report.csv
rm -f $SINGLE_REPORT_FILE

# Read in the conf files into an array
while read line ; do arrayProfiles[c++]="$line" ; done < <(cat ${AWS_PROFILES_CONF})

# Use this section to loop through all profiles listed in credentials file
#profiles=$( awk -F"\\\]|\\\[" '/^\[/{print $2}' ~/.aws/credentials)

# loop through multiple accounts
for profile in ${arrayProfiles[*]}; do
        reportStatus=
  printf "Creating credential report for %s.\\n" "$profile"
        until [ "$reportStatus" == 'COMPLETE' ]; do
                reportStatus=$(aws --profile "$profile" --output=json iam generate-credential-report | grep State | awk -F\" '{print $4}')
                if [ "$reportStatus" != 'COMPLETE' ]; then
#                       echo "Waiting on report generation...( %s )" "$reportStatus"
                        printf "Waiting on report generation...( %s )" "$reportStatus"
                        sleep 1
                fi
        done
        printf "\\nReport iam_credential_report_"$profile".csv created.\\n"
        printf "Retrieving credential report for %s\\n\\n" "$profile"
        $(aws --profile "$profile" --output=json iam get-credential-report | grep Content | awk -F\" '{print $4}' | base64 -d > iam_credential_report_"$profile".csv)

#       sed -i '1d' iam_credential_report_"$profile".csv
#       cat iam_credential_report_"$profile".csv >> $SINGLE_REPORT_FILE

done

awk 'FNR==1 && NR!=1{next;}{print}' *.csv > $SINGLE_REPORT_FILE
