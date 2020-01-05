#!/bin/bash

set -ue

IMPORT_DIR=imported
CONVERT_DIR=converted
TF_COMMON=tf/common
TF_CONVERT=tf/convert

rm -rf $CONVERT_DIR
mkdir -p $CONVERT_DIR
# cp $TF_COMMON/*tf $CONVERT_DIR
# cp $TF_CONVERT/*tf $CONVERT_DIR

cp $IMPORT_DIR/*{tfstate,tf} $CONVERT_DIR
cd $CONVERT_DIR
terraform init
terraform plan
