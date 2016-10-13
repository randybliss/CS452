#!/bin/bash
function set_awskey() {
  export AWS_ACCESS_KEY="$1"
  export AWS_ACCESS_KEY_ID="$1"
  export AWS_SECRET_KEY="$2"
  export AWS_SECRET_ACCESS_KEY="$2"
}

function determineVpcEnv() {
  unset VPC_ENV
  echo "if contains({AccountAliases: [\"eureka\"]}) then \"eureka\" elif contains({AccountAliases: [\"dev\"]}) then \"dev\" elif contains({AccountAliases: [\"test\"]}) then \"test\" elif contains({AccountAliases: [\"prod\"]}) then \"prod\" else empty end" > account-filter
  VPC_ENV=`aws iam list-account-aliases | jq -f account-filter | tr -d '"'`
  rm account-filter
}

if [[ "$0" == *setAccount.sh ]]
then
  echo "This script must be invoked by calling 'source $0' not '<path>/$0'"
  exit 1
fi

export -f set_awskey
echo "Obtain an AWS token using fsglobal credentials at https://dptservices.familysearch.org/aws/"
echo "NOTE this will set all AWS calls in this terminal from this point on to be using the new keys"
unset access
unset secret
echo "ACCESS KEY:"
read -a access
echo "SECRET KEY:"
read -a secret
set_awskey ${access} ${secret}
unset access
unset secret
if [ -f ~/.awssecret ] && [ ! -f ~/.awssecreteureka ]; then
  mv ~/.awssecret ~/.awssecreteureka
fi

echo ${AWS_ACCESS_KEY_ID} > ~/.awssecret
echo ${AWS_SECRET_ACCESS_KEY} >> ~/.awssecret