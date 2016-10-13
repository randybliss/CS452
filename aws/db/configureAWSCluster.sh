#!/bin/bash

usage() {
 echo '# Arguments accepted:
#     --tag required  - user tag (usually your initials) - when combined with reference tag uniquely identifies the cluster
#     --configFile required - Tree Foundation .yml config file used to start the Tree Foundation application
#     --nt optional  - node instance type - default="hi1.4xlarge"
#     --bp optional  - master node bid price - default="0.00" which causes the master node to be an"demand" instance
#     --num required  - core nodes qty - # of core nodes to start
#     --az  optional  - availability zone - default="us-east-1e"
#     --reg optional  - region - default="us-east-1"
#'
}

if [ -z "$HOST_DIR" ]; then
  source ./includes/functions.sh
fi

if [ ! -f ~/.awssecret ]; then
  if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
    echo "AWS secret key id must be set in AWS_ACCESS_KEY_ID environment variable to run this script"
    exit 1
  fi
  if [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
    echo "AWS secret key must be set in AWS_SECRET_ACCESS_KEY environment variable to run this script"
    exit 1
  fi
  echo $AWS_ACCESS_KEY_ID > ~/.awssecret
  echo $AWS_SECRET_ACCESS_KEY >> ~/.awssecret
fi

if [[ -z $REFERENCE_TAG ]]; then
  REFERENCE_TAG="tfapp"
fi

#SCRIPT_DIR=$(dirname $0)
#SERVER_PREFIX="TfAppCluster"

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
    -cf|--configFile)
    TF_CONFIG_YML="$1"
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
    *)
    echo "unknown argument type $key - exiting"
    usage
    exit $E_BADARGS
    ;;
esac
done

if [ -z "$HOST_DIR" ]; then
  setup-tfapp-run-environment
fi

if [ -z "$USER_TAG" ]; then
  echo "Must specify user tag"
  usage
  exit $E_BADARGS
fi

if [ -d $CONFIG_DIR ]; then
  load_cluster_config
else
  mkdir -p $CONFIG_DIR
fi

if [ -z "$INSTANCE_TYPE" ]; then
  if [ "$CONF_CORE_INSTANCE_TYPE" ]; then
    read -p "Node instance type is: $CONF_CORE_INSTANCE_TYPE - do you want to keep it (Y/n)? " answer
    if [ -z "$answer" ] || [[ $answer = [Yy] ]]; then
      INSTANCE_TYPE=$CONF_CORE_INSTANCE_TYPE
    fi
  fi
  if [ -z "$INSTANCE_TYPE" ]; then
    count=`wc -l $SCRIPT_DIR/helpers/types.txt | awk '/types.txt/ {print $1}'`
    echo "Select node instance type from the following:"
    PS3="(enter selection 1-$count)? "; select answer in `cat $SCRIPT_DIR/helpers/types.txt`; do
      INSTANCE_TYPE=$answer
      break
    done
  fi
fi
echo $INSTANCE_TYPE > $CONFIG_DIR/CoreNodeInstanceType

while [ -z "$BID_PRICE" ]; do
  if [ "$CONF_CORE_BID_PRICE" ]; then
    read -p "Node bid price (enter '0' for demand instances) [$CONF_CORE_BID_PRICE]: " answer
    if [ -z "$answer" ]; then
      BID_PRICE=$CONF_CORE_BID_PRICE
    else
      BID_PRICE=$answer
    fi
  else
    read -p "Enter node bid price (enter '0' for demand instance): " BID_PRICE
    if [ -z "$BID_PRICE" ]; then
      BID_PRICE=0
    fi
  fi
  PRICE=$BID_PRICE
  validate_price
  if [ "$VALID" == "bad" ]; then
    unset CORE_BID_PRICE
  elif [ "$VALID" == "demand" ]; then
    BID_PRICE=0
  fi
done
echo $BID_PRICE > $CONFIG_DIR/CoreNodeBidPrice

while [ -z "$NODE_COUNT" ]; do
  if [ "$CONF_CORE_SERVER_COUNT" ]; then
    read -p "Enter number of nodes [$CONF_CORE_SERVER_COUNT]: " answer
    if [ -z "$answer" ]; then
      NODE_COUNT=$CONF_CORE_SERVER_COUNT
    else
      NODE_COUNT=$answer
    fi
  else
    read -p "Enter number of nodes: " NODE_COUNT
  fi
done
echo $NODE_COUNT > $CONFIG_DIR/NumCoreNodes
echo
if [ -z "$REGION" ]; then
  if [ "$CONF_REGION" ]; then
    read -p "Region is: $CONF_REGION - do you want to keep it (Y/n)? " answer
    if [ -z "$answer" ] || [[ $answer = [Yy] ]]; then
      REGION=$CONF_REGION
    fi
  fi
  if [ -z "$REGION" ]; then
    count=`wc -l $SCRIPT_DIR/helpers/regions.txt | awk '/regions.txt/ {print $1}'`
    echo "Select region from the following:"
    PS3="(enter selection 1-$count)? "; select answer in `cat $SCRIPT_DIR/helpers/regions.txt`; do
      REGION=$answer
      break
    done
  fi
fi
echo $REGION > $CONFIG_DIR/Region
if [ -z "$AVAILABILITY_ZONE" ]; then
  if [ "$CONF_AVAILABILITY_ZONE" ]; then
    read -p "Availability zone is: $CONF_AVAILABILITY_ZONE - do you want to keep it (Y/n)? " answer
    if [ -z "$answer" ] || [[ $answer = [Yy] ]]; then
      AVAILABILITY_ZONE=$CONF_AVAILABILITY_ZONE
    fi
  fi
  if [ -z "$AVAILABILITY_ZONE" ]; then
    get_avail_zone
    AVAILABILITY_ZONE=$zone
  fi
fi
echo $AVAILABILITY_ZONE > $CONFIG_DIR/AvailabilityZone
echo
echo Configuration settings for $SERVER_PREFIX:$USER_TAG-$REFERENCE_TAG
echo
echo User Tag is: $USER_TAG
echo Configuration .yml file is: $TF_CONFIG_YML
echo
echo Node instance type is: `cat $CONFIG_DIR/CoreNodeInstanceType`
echo Node bid price is: `cat $CONFIG_DIR/CoreNodeBidPrice`
echo Number of nodes to start is: `cat $CONFIG_DIR/NumCoreNodes`
echo
echo Region is: `cat $CONFIG_DIR/Region`
echo Availability zone is: `cat $CONFIG_DIR/AvailabilityZone`
echo