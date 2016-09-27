#!/bin/bash
E_BADARGS=65
USE_RAID="TRUE"
CLUSTER_HOST="unknown"
IN_VPC=""
VPC_ENV=""
EUREKA_ACCOUNT='752435680812'
DEV_ACCOUNT='074150922133'
TEST_ACCOUNT='643055571372'
PROD_ACCOUNT='914248642252'
AMI_SEC_GROUP_NAME='tf-etl-ami-build'
EUREKA_SEC_GROUP_NAME='tf-webapp'
APP_SEC_GROUP_NAME='tf-app'
EUREKA_KEY_NAME='tf-dev'
DEV_VPC_KEY_NAME='vpc-instance'
AUX_VPC_KEY_NAME='adhoc-tf-dev'
TEST_VPC_KEY_NAME='adhoc-tf-test'
PROD_VPC_KEY_NAME='adhoc-tf-prod'

DEV_VPC_NAME='development-fh5-useast1-primary'
TEST_VPC_NAME='test-fh5-useast1-primary'
PROD_VPC_NAME='prod-fh5-useast1-primary'
DEV_AUX_VPC_NAME='development-fh5-useast1-aux1'
TEST_AUX_VPC_NAME='test-fh5-useast1-aux1'
PROD_AUX_VPC_NAME='prod-fh5-useast1-aux1'

ACCOUNT=${EUREKA_ACCOUNT}
KEY_NAME=${EUREKA_KEY_NAME}
