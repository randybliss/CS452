#!/bin/bash
usage() {
  echo '# Arguments accepted:
#     --tag - required  - cassandra cluster tag - uniquely identifies this cluster
#     --nt - optional  - node instance type - default="c1.large"
#     --bp - optional  - node bid price - default="0.00" which causes the master node to be an"demand" instance
#     --num - required  - nodes qty - # of nodes to start
#     --az  - optional  - availability zone - default="us-east-1e"
#     --help optional - display usage info
#'
}

if [ -z "$HOST_DIR" ]; then
  source ./includes/functions.sh
fi
echo "HOST_DIR=$HOST_DIR"


if [ ! -f ~/.awssecret ]; then
  if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
    echo "AWS secret key id must be set in ~/.awssecret file or AWS_ACCESS_KEY_ID environment variable to run this script"
    exit 1
  fi
  if [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
    echo "AWS secret key must be set in ~/.awssecret file or AWS_SECRET_ACCESS_KEY environment variable to run this script"
    exit 1
  fi
  echo $AWS_ACCESS_KEY_ID > ~/.awssecret
  echo $AWS_SECRET_ACCESS_KEY >> ~/.awssecret
fi

REGION="us-west-2"
USER_TAG="db"
INSTANCE_TYPE="t2.micro"

# Parse command line parameters
while [[ $# -ge 1 ]]
do
key="$1"
shift

case $key in
    -t|--tag)
    USER_TAG="$1"
    shift
    ;;
    -r|--ref)
    echo "--ref tag is deprecated - do not use - ignoring"
    shift
    ;;
    --nt)
    INSTANCE_TYPE="$1"
    shift
    ;;
    --bp)
    BID_PRICE="$1"
    shift
    ;;
    --num)
    NODE_COUNT="$1"
    shift
    ;;
    --az)
    AVAILABILITY_ZONE="$1"
    shift
    ;;
    --reg)
    REGION="$1"
    shift
    ;;
    --help)
    echo Help requested usage is:
    usage
    exit 0
    ;;
    *)
    echo "unknown argument type $key - exiting"
    usage
    exit $E_BADARGS
    ;;
esac
done

setup-run-environment

echo "User is $TF_USER"
echo "Using tag: $USER_TAG"

rm -rf $CONFIG_DIR >/dev/null 2>&1

if [ -d $CONFIG_DIR ]; then
  load_cluster_config
else
  configure_cluster
fi

if [ -z "$INSTANCE_TYPE" ]; then
  if [ -z "$CONF_CORE_INSTANCE_TYPE" ]; then
    configure_cluster
  fi
  INSTANCE_TYPE=$CONF_CORE_INSTANCE_TYPE
fi
if [ -z "$BID_PRICE" ]; then
  if [ -z "$CONF_CORE_BID_PRICE" ]; then
    configure_cluster
  fi
  BID_PRICE=$CONF_CORE_BID_PRICE
fi
if [ -z "$NODE_COUNT" ]; then
  if [ -z "$CONF_CORE_SERVER_COUNT" ]; then
    configure_cluster
  fi
  NODE_COUNT=$CONF_CORE_SERVER_COUNT
fi
if [ -z "$AVAILABILITY_ZONE" ]; then
  if [ -z "$CONF_AVAILABILITY_ZONE" ]; then
    configure_cluster
  fi
  AVAILABILITY_ZONE=$CONF_AVAILABILITY_ZONE
fi
if [ -z "$REGION" ]; then
  if [ -z "$CONF_REGION" ]; then
    CONF_REGION="us-west-2"
  fi
  REGION=$CONF_REGION
fi

echo Using instance type: $INSTANCE_TYPE
echo Using bid price: $BID_PRICE
echo Using number of node instances to start: $NODE_COUNT
echo Using region: $REGION

rm -rf $HOST_DIR > /dev/null 2>&1
mkdir -p $HOST_DIR
echo "DB-POSTGRES-$USER_TAG" > $HOST_DIR/clusterId
echo "$USER_TAG" > $HOST_DIR/creator

unset ami
MASTER_NAME="master"
echo  ".Images[] | if .Name == \"pg-db-server-image-master-$REFERENCE_TAG\" then .ImageId else empty end" > ami-filter
ami=`aws ec2 describe-images --region ${REGION} --owners $ACCOUNT | jq -f ami-filter | tr -d '"'`
rm ami-filter
if [[ -z $ami ]]; then
    echo "No postgres server ami found - exiting"
    exit 1
fi

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

echo "Creating Tree Foundation cassandra node instances from master image ${ami} ..."
#IAM_ROLE=tfAppRole
USER_DATA_FILE=userData.sh

echo "$INSTANCE_TYPE" > $HOST_DIR/coreInstanceType

cat <<EOF > ${USER_DATA_FILE}
#!/bin/bash
set -x
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
EOF

chmod +x ${USER_DATA_FILE}
#USER_DATA_ENCODED=`cat $USER_DATA_FILE | base64`
#let nodesPerZone=$NODE_COUNT/$ZONE_COUNT
#let extraNodes=$NODE_COUNT%$ZONE_COUNT
#zoneCount=0
#
#IFS=","
#for zoneSubnet in $zoneSubnetList; do
#  if [ -z "$zonesAndSubnets" ]; then
#    zonesAndSubnets=$zoneSubnet
#  else
#    zonesAndSubnets="$zonesAndSubnets $zoneSubnet"
#  fi
#done
#unset IFS
rm $HOST_DIR/coreInstanceIds >/dev/null 2>&1
rm $HOST_DIR/coreRequestIds >/dev/null 2>&1

#for zoneSubNet in $zonesAndSubnets; do
#  zoneSubnetArray=(`echo $zoneSubNet | tr ':' ' '`)
#  zone=${zoneSubnetArray[0]}
#  subnetId=${zoneSubnetArray[1]}
#  let zoneCount=$zoneCount+1
#  if [ $zoneCount -lt $ZONE_COUNT ]; then
#    nodeRequestCount=$nodesPerZone
#  else
#    let nodeRequestCount=$nodesPerZone+$extraNodes
#  fi

#  if [ "$IN_VPC" ]; then
    echo "Requesting $nodeRequestCount nodes in subnet: $subnetId for availability zone: $zone"
#  else
#    echo "Requesting $nodeRequestCount nodes in availability zone: $zone"
#  fi

  COMMON_PARAMS="--region ${REGION}"
  COMMON_PARAMS="${COMMON_PARAMS} --image-id ${ami}"
  COMMON_PARAMS="${COMMON_PARAMS} --key-name ${KEY_NAME}"
  COMMON_PARAMS="${COMMON_PARAMS} --user-data file://${USER_DATA_FILE}"
#  if [[ $IN_VPC ]]; then
    COMMON_PARAMS="${COMMON_PARAMS} --network-interfaces [{"
    COMMON_PARAMS="${COMMON_PARAMS}\"DeviceIndex\":0,"
    COMMON_PARAMS="${COMMON_PARAMS}\"Groups\":[\"$SECURITY_GROUP\"],"
    COMMON_PARAMS="${COMMON_PARAMS}\"SubnetId\":\"$subnetId\","
    COMMON_PARAMS="${COMMON_PARAMS}\"AssociatePublicIpAddress\":true"
    COMMON_PARAMS="${COMMON_PARAMS}}]"
#  else
#    COMMON_PARAMS="${COMMON_PARAMS} --security-groups ${APP_SECURITY_GROUP}"
#  fi
  COMMON_PARAMS="${COMMON_PARAMS} --placement AvailabilityZone=${zone}"

  COMMON_PARAMS="$COMMON_PARAMS --block-device-mappings ["
  COMMON_PARAMS="$COMMON_PARAMS{\"DeviceName\":\"/dev/sdb\","
  COMMON_PARAMS="$COMMON_PARAMS\"NoDevice\":\"\"},"
  COMMON_PARAMS="$COMMON_PARAMS{\"DeviceName\":\"/dev/sdc\","
  COMMON_PARAMS="$COMMON_PARAMS\"NoDevice\":\"\"},"
  COMMON_PARAMS="$COMMON_PARAMS{\"DeviceName\":\"/dev/sdd\","
  COMMON_PARAMS="$COMMON_PARAMS\"NoDevice\":\"\"},"
  COMMON_PARAMS="$COMMON_PARAMS{\"DeviceName\":\"/dev/sde\","
  COMMON_PARAMS="$COMMON_PARAMS\"NoDevice\":\"\"}"
  COMMON_PARAMS="$COMMON_PARAMS]"

  PARAMS="${COMMON_PARAMS} --instance-type ${INSTANCE_TYPE}"
  PARAMS="${PARAMS} --count ${NODE_COUNT}"

  if [ "$BID_PRICE" == "0" ]; then
    echo "Creating $NODE_COUNT PostgreSQL database server instances using parameters:"
    echo $PARAMS
    echo $nodeRequestCount core node demand instances
    info=`aws ec2 run-instances ${PARAMS}`
    echo "$info" | jq '.Instances[] | .InstanceId' | tr -d '"' > core-instance-ids
    echo "Instance reservation made - instance IDs are:"
    cat core-instance-ids
    cat core-instance-ids >> $HOST_DIR/coreInstanceIds
    rm core-instance-ids

  else
    PARAMS="--region ${REGION}"
    PARAMS="$PARAMS --spot-price $BID_PRICE"
    PARAMS="$PARAMS --instance-count $nodeRequestCount"
    PARAMS="$PARAMS --launch-specification {"
    PARAMS="$PARAMS\"ImageId\":\"${ami}\","
    PARAMS="$PARAMS\"InstanceType\":\"$INSTANCE_TYPE\","
    PARAMS="$PARAMS\"KeyName\":\"$KEY_NAME\","
#    if [[ $IN_VPC ]]; then
      PARAMS="$PARAMS\"NetworkInterfaces\":[{"
      PARAMS="$PARAMS\"DeviceIndex\":0,"
      PARAMS="$PARAMS\"Groups\":[\"$SECURITY_GROUP\"],"
      PARAMS="$PARAMS\"SubnetId\":\"$subnetId\","
      PARAMS="$PARAMS\"AssociatePublicIpAddress\":true}],"
#    else
#      PARAMS="$PARAMS\"SecurityGroups\":[\"$APP_SECURITY_GROUP\"],"
#    fi
    PARAMS="$PARAMS\"Placement\":{\"AvailabilityZone\":\"$zone\"},"
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
    PARAMS="$PARAMS}"

    echo "Requesting $NODE_COUNT core node instances with spot price \$$BID_PRICE - PARAMS:"
    echo $PARAMS
    requestInfo=`aws ec2 request-spot-instances $PARAMS`
    corereqids=`echo $requestInfo | jq '.SpotInstanceRequests[].SpotInstanceRequestId' | tr -d '"'`
    if [ -z "$corereqids" ]; then
      cancel_requests
      echo "spot instance request for core nodes failed: $requestInfo"
      exit 1
    fi
    echo $corereqids
    echo $corereqids >> $HOST_DIR/coreRequestIds
  fi
#done

#get core node instance ids for spot price instances
if [ "$BID_PRICE" != "0" ]; then
  count=0
  unset list
  for reqid in `cat $HOST_DIR/coreRequestIds`; do
    if [ $count -eq 0 ]; then
      list=$reqid
    fi
    let count=$count+1
    list="$list $reqid"
  done
  count=0
  rm $HOST_DIR/coreInstanceIds >/dev/null 2>&1
  while [ $count -lt $NODE_COUNT ]; do
    count=0
    requestInfo=`aws ec2 describe-spot-instance-requests --region $REGION --spot-instance-request-ids $list`
    requestStatii=`echo $requestInfo | jq '.SpotInstanceRequests[].Status.Code' | tr -d '"'`
    requestStates=`echo $requestInfo | jq '.SpotInstanceRequests[].State' | tr -d '"'`
    failedRequests=`echo $requestStates | grep "failed" | wc -l | awk '{print $1}'`
    echo "$failedRequests failed requests"
    if [ $failedRequests -gt 0 ]; then
      echo "Spot request for $NODE_COUNT nodes failed - exiting"
      cancel_requests
      exit 1
    fi

    for requestStatus in `echo $requestStatii`; do
      if [ "$requestStatus" == "price-too-low" ] || [ "$requestStatus" == "bad-request" ] || [ "$requestStatus" == "capacity-oversubscribed" ]; then
        echo "Spot request for $NODE_COUNT nodes failed - reason: $requestStatus - exiting"
        cancel_requests
        exit 1
      fi
      if [ "$requestStatus" == "fulfilled" ]; then
        let count=$count+1
      fi
    done
    echo "$count of $NODE_COUNT spot instance requests fulfilled"
    echo ""
    if [ $count -eq $NODE_COUNT ]; then
      instanceId=`echo $requestInfo | jq '.SpotInstanceRequests[].InstanceId' | tr -d '"'`
      echo $instanceId >$HOST_DIR/coreInstanceIds
    fi
    sleep 5s
  done
fi

#ensure nodes are running and setup host ips and ip names
created=0
lastCreated=0
loopCount=0
while [ $created -lt $NODE_COUNT ]
do
  runningInstances=`aws ec2 describe-instances --region ${REGION} | jq '.Reservations[] | .Instances[] | if .State.Name == "running" then . else empty end'`
  rm instance-info > /dev/null 2>&1
  created=0
  sleep 5s
  for id in `cat $HOST_DIR/coreInstanceIds`; do
    echo "if .InstanceId == \"$id\" and .State.Name == \"running\" then . else empty end" > ip-filter
    instanceInfo=`echo $runningInstances | jq -f ip-filter`
    if [[ $instanceInfo ]]; then
      echo $instanceInfo >> instance-info
      let created=$created+1
    fi
  done
  echo "PENDING - $created of $NODE_COUNT PostgreSQL server nodes running"
  if [ $created -ne 0 ] && [ $created -lt $NODE_COUNT ]; then
    if [ $created -eq $lastCreated ]; then
      let loopCount=$loopCount+1
      if [ $loopCount -gt 5 ]; then
        read -p "Not enough nodes - do you want to continue with $created nodes? (y/N) " answer
        if [ -z "$answer" ] || [[ $answer = [Nn] ]]; then
          terminate-core-nodes
          exit 1
        else
          NODE_COUNT=$created
        fi
      fi
    else
      lastCreated=$created
      loopCount=0
    fi
  fi
done
echo "SUCCESS - $NODE_COUNT PostgreSQL server nodes created and running"

#Write host dnsNames and ip addresses to hosts directory
cat instance-info > $HOST_DIR/coreInfo
cat instance-info | jq '.PublicIpAddress' | tr -d '"' > $HOST_DIR/corePublicIps
cat instance-info | jq '.PrivateIpAddress' | tr -d '"' > $HOST_DIR/corePrivateIps
cat instance-info | jq '.PublicDnsName' | tr -d '"' > $HOST_DIR/corePublicDnsNames
cat instance-info | jq '.PrivateDnsName' | tr -d '"' > $HOST_DIR/corePrivateDnsNames
head -n 1 $HOST_DIR/corePublicDnsNames > $HOST_DIR/masterPublicDnsName
masterPublicDnsName=`cat $HOST_DIR/masterPublicDnsName`
head -n 1 $HOST_DIR/corePublicDnsNames > $HOST_DIR/opsCenterNodePublicDnsName
sshOpsCenterIp=`cat $HOST_DIR/opsCenterNodePublicDnsName`
head -n 1 $HOST_DIR/corePrivateIps > $HOST_DIR/seedNodePrivateIps
tail -n 1 $HOST_DIR/corePrivateIps >> $HOST_DIR/seedNodePrivateIps

#if [ "$IN_VPC" ] && [ "$VPC_ENV" == "dev" ]; then
#  cat $HOST_DIR/corePrivateIps > $HOST_DIR/sshCoreIps
#  head -n 1 $HOST_DIR/corePrivateIps > $HOST_DIR/sshMaster
#  head -n 1 $HOST_DIR/corePrivateIps > $HOST_DIR/sshOpsCenter
#else
  cat $HOST_DIR/corePublicIps > $HOST_DIR/sshCoreIps
  head -n 1 $HOST_DIR/corePublicIps > $HOST_DIR/sshMaster
  head -n 1 $HOST_DIR/corePublicIps > $HOST_DIR/sshOpsCenter
#fi

#count=1
#for ip in `cat $HOST_DIR/sshCoreIps`; do
#  if [ $count -ne 1 ]; then
#    echo "$ip" >> $HOST_DIR/nonOpsCenterNodes
#  fi
#  if [ $count -ne 1 ] && [ $count -ne $NODE_COUNT ]; then
#    echo "$ip" >> $HOST_DIR/nonSeedNodes
#  fi
#  let count=$count+1
#done

rm instance-info > /dev/null 2>&1

#tag core nodes
count=1
for id in `cat $HOST_DIR/coreInstanceIds`; do
  sname="${SERVER_DISPLAY_NAME_PREFIX}-${USER_TAG}:${count}"
#  if [ $count -eq 1 ]; then
#    sname="${sname}_OpsCenter"
#  fi
  echo "tagging $id as $sname"
  aws ec2 create-tags --region ${REGION} --resources ${id} --tags Key=Name,Value=${sname} Key=Lookup,Value=${USER_TAG}-PostgreSQLNode
  let count=$count+1
done

opts="-i $KEY_FILE -o StrictHostKeyChecking=no"

#ensure we can ssh to all nodes
for ip in `cat $HOST_DIR/sshCoreIps`; do
  unset test
  while [ -z "$test" ]
  do
    echo PENDING-Waiting until ssh is available on $ip
    sleep 1s
    test=`ssh $opts $MUSER@$ip "pwd"`
  done
done

##perform ops center node specific setup steps
#sshOpsCenterIp=`cat $HOST_DIR/sshOpsCenter`
#scp $opts $SCRIPT_DIR/scripts/doStartOpsCenter.sh cassandra@$sshOpsCenterIp:/usr/local/bin
#ssh $opts cassandra@$sshOpsCenterIp 'sudo chmod +x /usr/local/bin/doStartOpsCenter.sh'
#
##setup drives, mountpoints and cassandra data directories on all nodes
#echo "Using pdsh to setup drives, mountpoints and data directories on cassandra nodes"
#export WCOLL=$HOST_DIR/sshCoreIps
#pdsh -l cassandra -R exec ssh -l %u -i $KEY_FILE -o "StrictHostKeyChecking no" %h "setupDrives.sh $USE_RAID"
#
#echo "Configuring Cassandra Cluster"
#. $SCRIPT_DIR/configureCassandra.sh --tag $USER_TAG
#
#echo "Starting and initializing Cassandra Cluster"
#. $SCRIPT_DIR/initializeCassandraCluster.sh --tag $USER_TAG
#
#echo "Cassandra node public dns names: "
#count=1
#for ip in `cat $HOST_DIR/sshCoreIps`; do
#  sname="${SERVER_DISPLAY_NAME_PREFIX}-${USER_TAG}:${count}"
#  if [ $count -eq 1 ]; then
#    sname="${sname} - opsCenter"
#  fi
#  echo "$sname - $ip"
#  let count=$count+1
#done
#echo ""
#echo "OpsCenter node public dns name: $sshOpsCenterIp"
rm dns-filter >/dev/null 2>&1
rm id-filter >/dev/null 2>&1
rm ip-filter >/dev/null 2>&1
rm jq-filter >/dev/null 2>&1
rm userData.sh >/dev/null 2>&1

echo "..... and we're done! ....."
