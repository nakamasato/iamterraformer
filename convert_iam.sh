#!/bin/bash

set -ue

FORCE=false
IMPORT_DIR=imported
CONVERT_DIR=converted
TF_COMMON=tf/common
TF_CONVERT=tf/convert

while getopts 'f' c
do
  case $c in
    f) FORCE=true ;;
  esac
done

if $FORCE; then
   rm -rf $CONVERT_DIR
   mkdir -p $CONVERT_DIR
   cp $IMPORT_DIR/iam.tfstate $CONVERT_DIR
fi

echo "[convert] copy"
cp $IMPORT_DIR/*tf $CONVERT_DIR
cp $TF_CONVERT/{main,output}.tf $CONVERT_DIR
cd $CONVERT_DIR
echo "[convert] copy done"

echo "[convert] mkdir"
for resource in role group user policy; do
    mkdir -p $resource;
done
echo "[convert] mkdir done"

echo "[convert] init"
terraform init

echo "[convert] iamp mv tf"
if [ -f iamp.tf ]; then
    mv iamp.tf policy
fi
echo "[convert] iamp mv tf done"

echo "[convert] iamp mv state"
for r in `terraform state list | grep '^aws_iam_policy\.'`; do terraform state mv $r module.policy.$r; done
rm -f terraform.tfstate.*.backup
echo "[convert] iamp mv state done"

echo "[convert] iamp create policy/output.tf"
content=`terraform state list | grep '^module\.policy\.aws_iam_policy\.' | sed 's/module.policy.\(.*\)/    \(\1.name\) = \1,/'`;
printf "output\"policies\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > policy/output.tf
echo "[convert] iamp create policy/output.tf done"

terraform plan -target=module.policy
echo "[convert] iamp done"

