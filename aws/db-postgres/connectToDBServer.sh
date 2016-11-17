#!/bin/bash
usage() { '# Arguments accepted:
#     --tag required  - user tag (usually your initials) - when combined with reference tag uniquely identifies the cluster
#     --ref optional  - reference tag - when combined with user tag uniquely identifies the AMI used to create your instances - default: etl
#'
}

source ./includes/functions.sh

CLUSTER_TAG='db'

# Parse command line parameters
while [[ $# > 1 ]]
do
key="$1"
shift

case $key in
    -t|--tag)
    CLUSTER_TAG="$1"
    shift
    ;;
    -r|--ref)
    echo "--ref tag is deprecated - do not use - ignoring"
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
  echo "Must specify user tag"
  usage
  exit $E_BADARGS
else
  echo "Using user tag: $USER_TAG"
fi

echo Using region: $REGION

if [ ! -d $HOST_DIR ]; then
  echo "Cluster for tag: $USER_TAG not available - exiting"
fi

masterIpAddress=`head -n 1 $HOST_DIR/sshMaster`
ssh -i $KEY_FILE -o StrictHostKeyChecking=no $MUSER@$masterIpAddress
