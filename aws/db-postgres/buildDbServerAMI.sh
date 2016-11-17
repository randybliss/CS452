#!/bin/bash
usage() {
  echo '# Check for proper number of command line args.
# Arguments accepted:
#     --tag - optional - user tag which uniquely identifies your AMI - default="master"
#     --reg - optional - region - default: us-west-2
#     --ami - optional - base AMI - default: Ubuntu 14.04 LTS (ami-018c9568)
#'
}

source ./includes/functions.sh

E_BADARGS=65
USER_TAG='master'
SCRIPT_DIR=$(dirname $0)
BASE_AMI=ami-ba21fada       #Ubuntu server 16.04LTS
REGION=us-west-2
DATABASE_TYPE=postgreSQL
INSTANCE_TYPE='t2.micro'

# Parse command line parameters
while [[ $# > 1 ]]
do
key="$1"
shift

case $key in
    -t|--tag)
    USER_TAG="$1"
    shift
    ;;
    --reg)
    REGION="$1"
    shift
    ;;
    --ami)
    BASE_AMI="$1"
    shift
    ;;
    *)
    echo "unknown argument type $key - exiting"
    usage
    exit $E_BADARGS
    ;;
esac
done

setup-run-environment


if [ -z "$USER_TAG" ]; then
  echo "Must specify user tag (usually your initials)"
  exit $E_BADARGS
else
  echo "Using user tag: $USER_TAG"
fi

echo "Using reference tag: $REFERENCE_TAG"
echo "Using region: $REGION"

 dir=`dirname $0`
#determine if ami already exists and delete it
unset ami
echo  ".Images[] | if .Name == \"pg-db-server-image-$USER_TAG-$REFERENCE_TAG\" then .ImageId else empty end" > ami-filter
ami=`aws ec2 describe-images --region ${REGION} --owners $ACCOUNT | jq -f ami-filter | tr -d '"'`
rm ami-filter
if [[ $ami ]]; then
  echo "AMI already exists - deleting $ami ..."
  echo ".Images[] | if .ImageId == \"$ami\" then .BlockDeviceMappings[0].Ebs.SnapshotId else empty end" > snapshot-filter
  snapshot=`aws ec2 describe-images --region ${REGION} --owners $ACCOUNT | jq -f snapshot-filter | tr -d '"'`
  rm snapshot-filter
  echo "Associated snapshot to be deleted: $snapshot"
  aws ec2 deregister-image --region ${REGION} --image-id $ami
fi
echo "Creating PostgreSQL AMI server instance from master image ${BASE_AMI}"

unset vpc
echo ".Vpcs[] | if contains({IsDefault: true}) then .VpcId else empty end" > vpc-filter
vpc=`aws ec2 describe-vpcs --region ${REGION} | jq -f vpc-filter | tr -d '"'`
rm vpc-filter

unset secGroup
aws ec2 describe-security-groups --region ${REGION} >temp-sec-groups
echo ".SecurityGroups[] | if .GroupName == \"$SEC_GROUP_NAME\" and .VpcId == \"$vpc\" then .GroupId else empty end" > group-filter
secGroup=`cat temp-sec-groups | jq -f group-filter | tr -d '"'`
rm group-filter
rm temp-sec-groups
SECURITY_GROUP=${secGroup}

unset availzones
echo ".Subnets[] | if .VpcId == \"$vpc\" then .AvailabilityZone + \":\" + .SubnetId else empty end" > subnet-filter
availzones=`aws ec2 describe-subnets --region ${REGION} | jq -f subnet-filter | tr -d '"'`
rm subnet-filter

count=`echo "$availzones" | wc -l | awk '{print $1}'`
echo "Select availability zone / subnet from the following:"
PS3="(enter selection 1-${count})? "; select answer in ${availzones}; do
    zonesubnet=(`echo $answer | tr ':' ' '`)
    zone=${zonesubnet[0]}
    subnetId=${zonesubnet[1]}
    unset zonesubnet
    echo "Zone: $zone"
    echo "id: $subnetId"
    break
done

echo "Security Group: $SECURITY_GROUP"
echo "Zone: $zone"
echo "vpc: $vpc"

#  SECURITY_GROUP=tf-etl-ami-build
#  zone='${REGION}d'

USER_DATA_FILE=setupScript.sh

if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
  echo "AWS secret key id must be set in AWS_ACCESS_KEY_ID environment variable to run this script"
  exit 1
fi
if [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
  echo "AWS secret key must be set in AWS_SECRET_ACCESS_KEY environment variable to run this script"
  exit 1
fi

cat <<EOF > ${USER_DATA_FILE}
#!/bin/bash
set -x
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "initializing" > /home/ubuntu/instanceStatus
MUSER=$MUSER
EOF

cat $SCRIPT_DIR/helpers/postgreSQLSetupScript.sh >> ${USER_DATA_FILE}

chmod +x ${USER_DATA_FILE}

PARAMS="--region ${REGION}"
PARAMS="${PARAMS} --image-id ${BASE_AMI}"
PARAMS="${PARAMS} --count 1"
PARAMS="${PARAMS} --key-name ${KEY_NAME}"
PARAMS="${PARAMS} --user-data file://${USER_DATA_FILE}"
PARAMS="${PARAMS} --instance-type ${INSTANCE_TYPE}"
#if [[ $IN_VPC ]]; then
  PARAMS="${PARAMS} --network-interfaces [{"
  PARAMS="$PARAMS\"DeviceIndex\":0,"
  PARAMS="$PARAMS\"Groups\":[\"$secGroup\"],"
  PARAMS="$PARAMS\"SubnetId\":\"$subnetId\","
  PARAMS="$PARAMS\"AssociatePublicIpAddress\":true"
  PARAMS="$PARAMS}]"
#else
#  PARAMS="${PARAMS} --security-groups ${SECURITY_GROUP}"
#fi
PARAMS="${PARAMS} --placement AvailabilityZone=${zone}"
PARAMS="$PARAMS --block-device-mappings ["
PARAMS="$PARAMS{\"DeviceName\":\"/dev/sdb\","
PARAMS="$PARAMS\"NoDevice\":\"\"},"
PARAMS="$PARAMS{\"DeviceName\":\"/dev/sdc\","
PARAMS="$PARAMS\"NoDevice\":\"\"},"
PARAMS="$PARAMS{\"DeviceName\":\"/dev/sdd\","
PARAMS="$PARAMS\"NoDevice\":\"\"},"
PARAMS="$PARAMS{\"DeviceName\":\"/dev/sde\","
PARAMS="$PARAMS\"NoDevice\":\"\"}"
PARAMS="$PARAMS]"
#PARAMS="${PARAMS} --iam-profile ${IAM_ROLE}"

echo $PARAMS
info=`aws ec2 run-instances ${PARAMS}`
instanceId=`echo "$info" | jq '.Instances[0].InstanceId' | tr -d '"'`
if [ -z "$instanceId" ]; then
  echo $info
  echo "Unable to create instance - aborting"
  exit 1
fi
echo "Instance reservation made - instance ID is $instanceId"

rm -f ${USER_DATA_FILE}

created=0
while [ $created -lt 1 ]
do
  echo "PENDING - $created of 1 AMI pattern instances created"
  sleep 5s
  echo ".Reservations[] | .Instances[] | if .InstanceId == \"$instanceId\" and .State.Name == \"running\" then .InstanceId  else empty end" > id-filter
  aws ec2 describe-instances --region ${REGION} | jq -f id-filter  | tr -d '"' > test_file
  created=`wc -l test_file | awk '/test_file/ {print $1}'`
done
echo ".Reservations[] | .Instances[] | if .InstanceId == \"$instanceId\" and .State.Name == \"running\" then .PublicDnsName  else empty end" > dns-filter
instanceDNS=`aws ec2 describe-instances --region ${REGION} | jq -f dns-filter | tr -d '"'`
echo ".Reservations[] | .Instances[] | if .InstanceId == \"$instanceId\" and .State.Name == \"running\" then .PublicIpAddress  else empty end" > public-ip-filter
instancePublicIp=`aws ec2 describe-instances --region ${REGION} | jq -f public-ip-filter | tr -d '"'`
echo ".Reservations[] | .Instances[] | if .InstanceId == \"$instanceId\" and .State.Name == \"running\" then .PrivateIpAddress  else empty end" > private-ip-filter
instancePrivateIp=`aws ec2 describe-instances --region ${REGION} | jq -f private-ip-filter | tr -d '"'`
echo "SUCCESS - AMI master instance created instance ID is $instanceId - instance DNS name is $instanceDNS"
echo "InstancePublicIpAddress is $instancePublicIp - InstancePrivateIpAddress is $instancePrivateIp"
rm test_file
rm dns-filter
rm public-ip-filter
rm private-ip-filter

#if [ -z "$IN_VPC" ] || [ "$VPC_ENV" == "dev" ]; then
  sshIpAddress=$instancePublicIp
#else
#  sshIpAddress=$instancePrivateIp
#fi

unset test
echo "WAITING for instance setup script to finish"
while [ "$test" != "ready" ]
do
   test=`ssh -i $KEY_FILE -o StrictHostKeyChecking=no ubuntu@$sshIpAddress "cat /home/ubuntu/instanceStatus"`
   echo "Setup script status: ${test}"
   sleep 5s
done
echo "Instance DNS is: $instanceDNS"
opts="-i $KEY_FILE -o StrictHostKeyChecking=no"

#make fs user the owner of /usr/local/bin
#ssh $opts fs@$sshIpAddress 'sudo chown -R fs:fs /usr/local/bin'

#install docker
#scp $opts $SCRIPT_DIR/scripts/installDocker.sh fs@$sshIpAddress:/usr/local/bin
#ssh $opts fs@$sshIpAddress 'installDocker.sh'

#create and copy docker container setup script
#echo "#!/bin/bash" > tfAppBaseDockerSetup.sh
#cat $SCRIPT_DIR/helpers/tfappAMIsetupScript.sh >> tfAppBaseDockerSetup.sh
#chmod +x tfAppBaseDockerSetup.sh
#scp $opts tfAppBaseDockerSetup.sh fs@$sshIpAddress:/usr/local/bin
#rm tfAppBaseDockerSetup.sh
#scp $opts $SCRIPT_DIR/helpers/tfappDockerSetup.sh fs@$sshIpAddress:/usr/local/bin

#install common scripts (required by all TfApp servers)
#scp $opts $SCRIPT_DIR/scripts/setupDrives.sh fs@$sshIpAddress:/usr/local/bin
#scp $opts $SCRIPT_DIR/scripts/runCassandra.sh fs@$sshIpAddress:/usr/local/bin
#scp $opts $SCRIPT_DIR/scripts/doPullAppCode.sh fs@$sshIpAddress:/usr/local/bin
#scp $opts $SCRIPT_DIR/scripts/doInstallAppCode.sh fs@$sshIpAddress:/usr/local/bin
#scp $opts $SCRIPT_DIR/scripts/doSetupTfAppServer.sh fs@$sshIpAddress:/usr/local/bin
#scp $opts $SCRIPT_DIR/scripts/doSetupSymLinks.sh fs@$sshIpAddress:/usr/local/bin
#scp $opts $SCRIPT_DIR/scripts/startTF fs@$sshIpAddress:/usr/local/bin
#scp $opts $SCRIPT_DIR/scripts/startTFDocker.sh fs@$sshIpAddress:/usr/local/bin
#scp $opts $SCRIPT_DIR/scripts/doStartTfAppDocker.sh fs@$sshIpAddress:/usr/local/bin
#scp $opts $SCRIPT_DIR/helpers/tfappAMIsetupScript.sh fs@$sshIpAddress:/usr/local/bin
#scp $opts $SCRIPT_DIR/scripts/doPublishDockerImage.sh fs@$sshIpAddress:/usr/local/bin

#install s3cmd
#scp $opts ~/.awssecret fs@$sshIpAddress:/home/fs
#scp $opts $SCRIPT_DIR/scripts/installS3Cmd.sh fs@$sshIpAddress:/home/fs
#ssh $opts fs@$sshIpAddress 'chmod +x /home/fs/installS3Cmd.sh'
#if [ -f ~/.s3cfg ]; then
#  scp $opts ~/.s3cfg fs@$sshIpAddress:/home/fs
#fi
#ssh $opts fs@$sshIpAddress '/home/fs/installS3Cmd.sh'
#ssh $opts fs@$sshIpAddress 'sudo chown -R fs:fs /usr/local/bin'
#
##generate ssh keys for master and slave nodes to talk to each other
#ssh $opts fs@$sshIpAddress 'ssh-keygen -t rsa -P "" -C "id_tf" -f  ~/.ssh/id_tf'
#ssh $opts fs@$sshIpAddress 'cat /home/fs/.ssh/id_tf.pub >> /home/fs/.ssh/authorized_keys'
#scp $opts $SCRIPT_DIR/helpers/sshConfig.txt fs@$sshIpAddress:/home/fs/.ssh/config
#
##load TfApp code and scripts
##ssh $opts fs@$sshIpAddress "doPullAppCode.sh --codeBucket $CODE_BUCKET"
#
#ssh $opts fs@$sshIpAddress 'rm ~/.awssecret'
#ssh $opts fs@$sshIpAddress 'rm ~/.s3cfg'
#
##Publish a base docker image to docker repository
#scp $opts $SCRIPT_DIR/scripts/doPublishDockerBaseImage.sh fs@$sshIpAddress:/usr/local/bin
#ssh $opts fs@$sshIpAddress "sudo doPublishDockerBaseImage.sh --tag $CLUSTER_TAG"
#ssh $opts fs@$sshIpAddress "rm /usr/local/bin/doPublishDockerBaseImage.sh"

echo "SUCCESS - INSTANCE SETUP COMPLETE"

#make sure existing AMI has been deleted
if [[ $ami ]]; then
  unset test
  echo  ".Images[] | if .ImageId == \"$ami\" then .ImageId else empty end" > ami-id-filter
  test=`aws ec2 describe-images --region ${REGION} --owners $ACCOUNT | jq -f ami-id-filter | tr -d '"'`
  while [[ $test ]]; do
    sleep 5s
    test=`aws ec2 describe-images --region ${REGION} --owners $ACCOUNT | jq -f ami-id-filter | tr -d '"'`
  done
  rm ami-id-filter
  sleep 10s
  aws ec2 delete-snapshot --region ${REGION} --snapshot-id ${snapshot}
fi

#read -p "Pausing for additional instance setup - press enter to continue" answer
echo "Creating AMI image from master instance ..."
aws ec2 create-image --region ${REGION} --instance-id $instanceId --name pg-db-server-image-$USER_TAG-$REFERENCE_TAG --description "Tree Foundation etl AMI"
unset ami
echo  ".Images[] | if .Name == \"pg-db-server-image-$USER_TAG-$REFERENCE_TAG\" and .State == \"available\" then .ImageId else empty end" > ami-filter
ami=`aws ec2 describe-images --region ${REGION} --owners $ACCOUNT | jq -f ami-filter | tr -d '"'`
while [[ -z $ami ]]; do
  sleep 5s
  ami=`aws ec2 describe-images --region ${REGION} --owners $ACCOUNT | jq -f ami-filter | tr -d '"'`
done
rm ami-filter
aws ec2 create-tags --region ${REGION} --resources ${ami} --tags Key=Name,Value=PostgresServerImage-$USER_TAG-$REFERENCE_TAG

echo "AMI successfully created - deleting master builder instance - instance ID is $instanceId"
aws ec2 terminate-instances --region ${REGION} --instance-ids ${instanceId}
rm dns-filter
rm id-filter
echo ".............and we're done!"

