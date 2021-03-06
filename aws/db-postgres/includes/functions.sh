#!/bin/bash
source ./includes/constants.sh
E_BADARGS=65
shopt -s extglob

load_cluster_config() {
  if [ -f $CONFIG_DIR/CoreNodeInstanceType ]; then
    CONF_CORE_INSTANCE_TYPE=`cat $CONFIG_DIR/CoreNodeInstanceType`
  fi
  if [ -f $CONFIG_DIR/CoreNodeBidPrice ]; then
    CONF_CORE_BID_PRICE=`cat $CONFIG_DIR/CoreNodeBidPrice`
  fi
  if [ -f $CONFIG_DIR/NumCoreNodes ]; then
    CONF_CORE_SERVER_COUNT=`cat $CONFIG_DIR/NumCoreNodes`
  fi
  if [ -f $CONFIG_DIR/AvailabilityZone ]; then
    CONF_AVAILABILITY_ZONE=`cat $CONFIG_DIR/AvailabilityZone`
  fi
  if [ -f $CONFIG_DIR/Region ]; then
    CONF_REGION=`cat $CONFIG_DIR/Region`
  fi
  if [ -f $CONFIG_DIR/ConfigFile ]; then
    CONF_TF_CONFIG_YML=`cat $CONFIG_DIR/ConfigFile`
  fi
}

validate_price() {
  unset VALID
  if [ $PRICE == 0 ] || [ $PRICE == 0.0 ] || [ $PRICE == 0.00 ] ; then
    VALID="demand"
    return
  fi
  if [[ $PRICE == ?([-+])+([0-9])?(.*([0-9])) ]] ||
     [[ $PRICE == ?(?([-+])*([0-9])).+([0-9]) ]]; then
     VALID="spot"
  else
    echo "Spot price argument $PRICE is not a valid decimal number"
    VALID="bad"
    return
  fi
  PRICE_CMP=`echo $PRICE '<' 0.001|bc -l`
  PRICE_CMP_HI=`echo $PRICE '>' 17.23|bc -l`
  if [ $PRICE_CMP -eq 1 ]; then
    echo "For \"spot\" instance billing type, you must specify an hourly price greater than 1 cent for your bid!"
    VALID="bad"
    return
  elif [ $PRICE_CMP_HI -eq 1 ]; then
    echo "For \"spot\" instance billing type, you must specify an hourly price less than \$17.23 for your bid!"
    VALID="bad"
    return
  else
    VALID="spot"
  fi
}

configure_cluster() {
  echo One or more required parameters are missing - invoking cluster configuration script
  PARAMS="--tag $USER_TAG"
  if [ "$INSTANCE_TYPE" ]; then
    PARAMS="$PARAMS --nt $INSTANCE_TYPE"
  fi
  if [ "$BID_PRICE" ]; then
    PARAMS="$PARAMS --bp $BID_PRICE"
  fi
  if [ "$NODE_COUNT" ]; then
    PARAMS="$PARAMS --num $NODE_COUNT"
  fi
  if [ "$AVAILABILITY_ZONE" ]; then
    PARAMS="$PARAMS --az $AVAILABILITY_ZONE"
  fi
  if [ "$REGION" ]; then
    PARAMS="$PARAMS --reg $REGION"
  fi
  if [ "$TF_CONFIG_YML" ]; then
    PARAMS="$PARAMS --configFile $TF_CONFIG_YML"
  fi
  . $SCRIPT_DIR/configureAWSCluster.sh $PARAMS
  load_cluster_config
}

get_avail_zone() {
    unset vpc
    echo ".Vpcs[] | if contains({IsDefault: true}) then .VpcId else empty end" > vpc-filter
    vpc=`aws ec2 describe-vpcs --region ${REGION} | jq -f vpc-filter | tr -d '"'`
    rm vpc-filter

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
}


cancel_requests() {
  if [ -f $HOST_DIR/coreRequestIds ]; then
    count=0
    unset list
    for reqid in `cat $HOST_DIR/coreRequestIds`; do
      if [ $count -eq 0 ]; then
        list=$reqid
      fi
      let count=$count+1
      list="$list $reqid"
    done
    aws ec2 cancel-spot-instance-requests --region $REGION --spot-instance-request-ids $list
  fi
  if [ -f $HOST_DIR/resourceManagerRequestId ]; then
    rmreqid=`head -n 1 $HOST_DIR/resourceManagerRequestId`
    aws ec2 cancel-spot-instance-requests --region $REGION --spot-instance-request-ids $rmreqid
  fi
  if [ -f $HOST_DIR/nameNodeRequestIds ]; then
    for nnid in `cat $HOST_DIR/nameNodeRequestIds`; do
      aws ec2 cancel-spot-instance-requests --region $REGION --spot-instance-request-ids $nnid
    done
  fi
}

terminate-core-nodes() {
  echo Terminating CORE nodes
  count=0
  unset list
  for id in `cat $HOST_DIR/coreInstanceIds`; do
    if [ $count -eq 0 ]; then
      list=$id
    fi
    let count=$count+1
    list="$list $id"
  done
  aws ec2 terminate-instances --region $REGION --instance-ids $list
}

copy-pipeline-scripts() {
  ssh $opts hadoop@$masterPublicDnsName 'rm /usr/local/bin/doRun*.sh'
  scp $opts $SCRIPT_DIR/scripts/doRunPrivacyMarking.sh hadoop@$masterPublicDnsName:/usr/local/bin
  scp $opts $SCRIPT_DIR/scripts/doRunJournalTransactionConversion.sh hadoop@$masterPublicDnsName:/usr/local/bin
  scp $opts $SCRIPT_DIR/scripts/doRunFixupRRS.sh hadoop@$masterPublicDnsName:/usr/local/bin
  scp $opts $SCRIPT_DIR/scripts/doRunComputeViews.sh hadoop@$masterPublicDnsName:/usr/local/bin
  scp $opts $SCRIPT_DIR/scripts/doRunReconcile.sh hadoop@$masterPublicDnsName:/usr/local/bin
  scp $opts $SCRIPT_DIR/scripts/doRunBulkLoadMapProcess.sh hadoop@$masterPublicDnsName:/usr/local/bin
  scp $opts $SCRIPT_DIR/scripts/doRunMigrationPipeline.sh hadoop@$masterPublicDnsName:/usr/local/bin
  scp $opts $SCRIPT_DIR/scripts/doSetupRunlogs.sh hadoop@$masterPublicDnsName:/usr/local/bin
}

setup-directories() {
  SCRIPT_PATH="${BASH_SOURCE[2]}";
  if ([ -h "${SCRIPT_PATH}" ]); then
    while([ -h "${SCRIPT_PATH}" ]); do SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
  fi
  pushd . > /dev/null
  cd `dirname ${SCRIPT_PATH}` > /dev/null
  export SCRIPT_DIR=`pwd`;
  popd  > /dev/null

  PROJECT_PATH=`dirname ${SCRIPT_DIR}` > /dev/null
  if ([ -h "${PROJECT_PATH}" ]); then
    while([ -h "${PROJECT_PATH}" ]); do PROJECT_PATH=`readlink "${PROJECT_PATH}"`; done
  fi
  pushd . > /dev/null
  cd `dirname ${PROJECT_PATH}` > /dev/null
  export PROJECT_DIR=`pwd`;
  popd  > /dev/null
  echo "project path is $PROJECT_DIR : script path is $SCRIPT_DIR"
}

setup-run-environment() {
  CLUSTER_TYPE='pg'
  if [ -z "$CLUSTER_TAG" ]; then
    if [ -z "$USER_TAG" ]; then
      echo "--tag argument missing - you must provide a unique or shared tag to run this script"
      exit $E_BADARGS
    else
      CLUSTER_TAG=$USER_TAG
    fi
  else
    USER_TAG=$CLUSTER_TAG
  fi
  CODE_BUCKET="tf-webapp-code/codesets/$CLUSTER_TAG-tfapp"

  if [ -z "$PROJECT_DIR" ]; then
    setup-directories
  fi

  export REGION="us-west-2"
  export AWS_DEFAULT_OUTPUT="json"

  KEY_FILE=~/.ssh/${KEY_NAME}.pem
  HOST_DIR=$SCRIPT_DIR/hosts/$CLUSTER_TYPE-$CLUSTER_TAG-$REFERENCE_TAG
  CONFIG_DIR=$SCRIPT_DIR/config/$CLUSTER_TYPE-$CLUSTER_TAG-$REFERENCE_TAG
  opts="-i $KEY_FILE -o StrictHostKeyChecking=no"
  if [ -f $HOST_DIR/masterPublicDnsName ]; then
    masterPublicDnsName=`cat $HOST_DIR/masterPublicDnsName`
  fi
  if [ -f $HOST_DIR/sshMaster ]; then
    sshMaster=`cat $HOST_DIR/sshMaster`
  fi
}

createHostsCSVFile() {
  i=0
  for string in `cat $HOST_DIR/corePublicDnsNames`; do
    dnsNames[i]=$string
    let i=$i+1
  done

  i=0
  for string in `cat $HOST_DIR/coreInstanceIds`; do
    instanceIds[i]=$string
    let i=$i+1
  done

  i=0
  for string in `cat $HOST_DIR/corePrivateIps`; do
    privateIps[i]=$string
    let i=$i+1
  done

  i=0
  for string in `cat $HOST_DIR/corePublicIps`; do
    publicIps[i]=$string
    let i=$i+1
  done

  i=0
  rm tf-$USER_TAG-hosts.csv >/dev/null 2>&1
  for string in `cat $HOST_DIR/corePublicDnsNames`; do
    echo "${dnsNames[i]},${instanceIds[i]},${privateIps[i]},${publicIps[i]}" >> tf-$USER_TAG-hosts.csv
    let i=$i+1
  done
}

unset JARS_DIR
USE_RAID="TRUE"
CLUSTER_HOST="unknown"
