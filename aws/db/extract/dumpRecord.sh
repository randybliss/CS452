#!/bin/bash

JOURNAL=""
ID=""
OUTPUT="./"

# Parse command line parameters
while [[ $# > 1 ]]
do
key="$1"
shift

case $key in
  -j|--journal)
  JOURNAL="$1"
  shift
  ;;
  -i|--id)
  ID="$1"
  shift
  ;;
  -o|--output)
  OUTPUT="$1"
  shift
  ;;
  *)
  echo "unknown argument type $key - exiting"
  exit 1
  ;;
esac
done


if [ -z "$JOURNAL" ]; then
  echo "JOURNAL argument must be provided to run this script"
  exit 1
fi

if [ -z "$ID" ]; then
  echo "ID argument must be provided to run this script"
  exit 1
fi

if [ ! -d "${OUTPUT}" ] ; then
  echo "$OUTPUT is not a directory";
  exit 1
fi

ssh -i ~/.ssh/vpc-instance-dev-fh5.pem -o StrictHostKeyChecking=no cassandra@10.36.181.132 "/home/cassandra/dse/bin/cqlsh -e \"select * from tf.${JOURNAL}_journal where entity_id = '${ID}'\"" >${OUTPUT}${ID}.${JOURNAL}.journal
