#!/bin/bash

SESSION=""

if [[ $# == 0 ]]; then
  echo "Usage: $0 [-s <admin session id>] [-u <beta username>] [--keep-files] [-k <keyspace>] <pid> [<pid>...]"
  echo "       at least one id is required"
  echo "       The session id is required unless you already have a dump of the person saved to a file named the PID"
fi

#SESSION=`curl -u kaychoro "https://beta.familysearch.org/tf/identity/login"`
#curl -H "Authorization: Bearer $SESSION" -X PUT "https://beta.familysearch.org/assignment-service/assignments/Engineer%20Admin"

# Parse args
if [[ "$1" = "-s" ]]; then
  SESSION="$2"
  shift; #take off the -s
  shift; #take off the session id
fi

if [[ "$1" = "-u" ]]; then
  USER="$2"
  shift; #take off the -u
  shift; #take off the user id
  printf "Enter ${USER}'s password: "
  SESSION=`curl -u $USER "https://beta.familysearch.org/tf/identity/login" 2>/dev/null`
  echo;
  curl -H "Authorization: Bearer $SESSION" -X PUT "https://beta.familysearch.org/assignment-service/assignments/Engineer%20Admin" 1>/dev/null 2>&1
  curl "https://beta.familysearch.org/tf/person/CURRENT?sessionId=${SESSION}" 1>/dev/null 2>&1
  curl "https://beta.familysearch.org/tf/person/CURRENT?sessionId=${SESSION}" 1>/dev/null 2>&1
fi

if [[ "$1" = "--keep-files" ]]; then
  KEEP_TEMPDIR="yes"
  shift; #take off the --keep-files
fi

KEYSPACE="tf"
if [[ "$1" = "-k" ]]; then
  KEYSPACE="$2"
  shift; #take off the -k
  shift; #take off the keyspace
fi

TEMPDIR=`mktemp -d journals-XXXXXXXXXX` || exit 1
for arg; do
  ID="$arg"
  if [[ -z "$SESSION" ]]; then
    if [ ! -f $ID ]; then
      echo "ERROR: You must supply an admin session id to retrieve $ID from the database"
      exit 1
    fi
    PERSON=`cat $ID`;
  else
    PERSON=`curl "https://beta.familysearch.org/tf/admin/person/${ID}/dump?sessionId=${SESSION}" 2>/dev/null`
    HTTP_ERROR=`echo $PERSON | grep "<title>" | sed -E 's/^.*<title>(.*)<\/title>.*$/\1/'`
    if [[ ! -z "$HTTP_ERROR" ]]; then
      echo "Error retrieving Person ${ID}: ${HTTP_ERROR}"
      echo "   Use the following command to see more details:"
      echo "      curl \"https://beta.familysearch.org/tf/admin/person/${ID}/dump?sessionId=${SESSION}\""
      continue
    fi
  fi
  for relation in `echo $PERSON | jq -e '.personAccessControlMap | keys[]' |  tr -d '"'`; do
    echo "Retrieving one-hop: $relation"
    ./dumpRecord.sh -j person -i $relation -o ${TEMPDIR}/
  done

  for relationship in `echo $PERSON | jq -e '.coupleAccessControlMap | keys[]' |  tr -d '"'`; do
    echo "Retrieving couple: $relationship"
    ./dumpRecord.sh -j couple -i $relationship -o ${TEMPDIR}/
  done
  for relationship in `echo $PERSON | jq -e 'if .couplesToRestore then .couplesToRestore | keys[] else "" end' |  tr -d '"'`; do
    echo "Retrieving couple: $relationship"
    ./dumpRecord.sh -j couple -i $relationship -o ${TEMPDIR}/
  done
  for relation in `echo $PERSON | jq -e 'if .couplesToRestore then .couplesToRestore[].husbandId else "" end' |  tr -d '"' | sort -u`; do
    echo "Retrieving one-hop: $relation"
    ./dumpRecord.sh -j person -i $relation -o ${TEMPDIR}/
  done
  for relation in `echo $PERSON | jq -e 'if .couplesToRestore then .couplesToRestore[].wifeId else "" end' |  tr -d '"' | sort -u`; do
    echo "Retrieving one-hop: $relation"
    ./dumpRecord.sh -j person -i $relation -o ${TEMPDIR}/
  done

  for relationship in `echo $PERSON | jq -e '.parentChildAccessControlMap | keys[]' |  tr -d '"'`; do
    echo "Retrieving parent child: $relationship"
    ./dumpRecord.sh -j parent_child -i $relationship -o ${TEMPDIR}/
  done
  for relationship in `echo $PERSON | jq -e 'if .parentChildsToRestore then .parentChildsToRestore | keys[] else "" end' |  tr -d '"'`; do
    echo "Retrieving parent child: $relationship"
    ./dumpRecord.sh -j parent_child -i $relationship -o ${TEMPDIR}/
  done
  for relation in `echo $PERSON | jq -e 'if .parentChildsToRestore then .parentChildsToRestore[].fatherId else "" end' |  tr -d '"' | sort -u`; do
    echo "Retrieving one-hop: $relation"
    ./dumpRecord.sh -j person -i $relation -o ${TEMPDIR}/
  done
  for relation in `echo $PERSON | jq -e 'if .parentChildsToRestore then .parentChildsToRestore[].motherId else "" end' |  tr -d '"' | sort -u`; do
    echo "Retrieving one-hop: $relation"
    ./dumpRecord.sh -j person -i $relation -o ${TEMPDIR}/
  done
  for relation in `echo $PERSON | jq -e 'if .parentChildsToRestore then .parentChildsToRestore[].childId else "" end' |  tr -d '"' | sort -u`; do
    echo "Retrieving one-hop: $relation"
    ./dumpRecord.sh -j person -i $relation -o ${TEMPDIR}/
  done
done

./importDumpedJournals.sh -k ${KEYSPACE} ${TEMPDIR}

[ ! -n "$KEEP_TEMPDIR" ] && rm -rf $TEMPDIR || echo "records preserved here: $TEMPDIR"
