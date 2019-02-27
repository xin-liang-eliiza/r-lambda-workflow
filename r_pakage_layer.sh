#!/bin/bash
set -x

VERSION=$1
KEY_PATH=$2
IMAGE_ID=$3
PACKAGE=$4

KEY_NAME=$(echo $KEY_PATH | rev | cut -d '/' -f 1 | cut -d '.' -f 2 | rev)

# create instance from R Lambda AMI
MyServerID=$(aws ec2 run-instances --image-id $IMAGE_ID --count 1 --instance-type t2.micro --key-name $KEY_NAME --query 'Instances[0].InstanceId' --output text)

MyServerCheckStatus=$(aws ec2 describe-instance-status --instance-id $MyServerID --query 'InstanceStatuses[0].SystemStatus.Status' --output text --output text)
while [ $MyServerCheckStatus != 'ok' ]; do
  sleep 10
  MyServerCheckStatus=$(aws ec2 describe-instance-status --instance-id $MyServerID --query 'InstanceStatuses[0].SystemStatus.Status' --output text --output text)
done

MyServerIP=$(aws ec2 describe-instances --instance-id $MyServerID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

# install R packages
ssh-keyscan -T 240 -H $MyServerIP &>> ~/.ssh/known_hosts
ssh -i $KEY_PATH ec2-user@$MyServerIP "mkdir -p /opt/R/new_library/R/library"
ssh -i ~/.ssh/kuba-appsilon.pem ec2-user@$MyServerIP "/opt/R/bin/Rscript -e 'chooseCRANmirror(graphics=FALSE, ind=34); install.packages(\"$PACKAGE\", lib = \"/opt/R/new_library/R/library\")'"

# create archive and download it
ssh -i $KEY_PATH ec2-user@$MyServerIP "cd /opt/R/new_library && zip -r packages.zip R/"
scp -i ~/.ssh/kuba-appsilon.pem ec2-user@$MyServerIP:/opt/R/new_library/packages.zip .
