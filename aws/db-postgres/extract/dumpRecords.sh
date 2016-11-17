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

filename="$ID"
IFS=$'\n'
for line in `cat $filename`
do
    (exec ./dumpRecord.sh -j $JOURNAL -i $line -o $OUTPUT/)
    echo "Processed id: $line"
done < "$filename"
