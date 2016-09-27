#!/bin/bash
if [[ "$0" == *novpc.sh ]]
then
  echo "This script must be invoked by calling 'source $0' not '<path>/$0'"
  exit 1
fi
if [ -f ~/.awssecreteureka ]; then
  cp ~/.awssecreteureka ~/.awssecret
  access=`head -n 1 ~/.awssecret`
  secret=`tail -n 1 ~/.awssecret`
setkeyfunctype=`type -t set_awskey`
if [ "$setkeyfunctype" ]; then
  set_awskey ${access} ${secret}
fi
  unset access
  unset secret
  unset set_awskey
else
  echo "No saved credentials detected - unable to restore non vpc credentials"
fi

