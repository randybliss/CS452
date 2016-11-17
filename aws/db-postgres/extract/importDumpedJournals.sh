#!/bin/bash

if [[ $# == 0 ]]; then
  echo "Usage: $0 [-k <keyspace>] <dir> [<dir>...]"
  echo "       at least one dir is required"
fi

KEYSPACE="tf"
if [[ "$1" = "-k" ]]; then
  KEYSPACE="$2"
  shift; #take off the -k
  shift; #take off the keyspace
fi

for arg; do
  TEMPDIR="$arg"
  echo "Importing records from dir: $TEMPDIR"

  if ls ${TEMPDIR}/*.person.journal 1> /dev/null 2>&1; then
    echo "Importing person journals"
    grep -h "0x" ${TEMPDIR}/*.person.journal | tr -d ' ' | tr '|' ',' | sed -E 's/^([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),/"INSERT INTO '$KEYSPACE'.person_journal (entity_id, record_id, sub_id, type, subtype, content) VALUES ("\'\'\\1\',\\2,\\3,\'\\4\',\'\\5\',/'' | tr -d '"' | sed 's/$/);/' | cqlsh
  else
    echo "No persons to import"
  fi
  if ls ${TEMPDIR}/*.couple.journal 1> /dev/null 2>&1; then
    echo "Importing couple journals"
    grep -h "0x" ${TEMPDIR}/*.couple.journal | tr -d ' ' | tr '|' ',' | sed -E 's/^([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),/"INSERT INTO '$KEYSPACE'.couple_journal (entity_id, record_id, sub_id, type, subtype, content) VALUES ("\'\'\\1\',\\2,\\3,\'\\4\',\'\\5\',/'' | tr -d '"' | sed 's/$/);/' | cqlsh
  else
    echo "No couples to import"
  fi
  if ls ${TEMPDIR}/*.parent_child.journal 1> /dev/null 2>&1; then
    echo "Importing parent child journals"
    grep -h "0x" ${TEMPDIR}/*.parent_child.journal | tr -d ' ' | tr '|' ',' | sed -E 's/^([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),/"INSERT INTO '$KEYSPACE'.parent_child_journal (entity_id, record_id, sub_id, type, subtype, content) VALUES ("\'\'\\1\',\\2,\\3,\'\\4\',\'\\5\',/'' | tr -d '"' | sed 's/$/);/' | cqlsh
  else
    echo "No parent childs to import"
  fi
done
