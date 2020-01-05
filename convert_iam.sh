#!/bin/bash

set -ue

FORCE=false
GROUP_MODULE_PATH=../../tf/modules/iam/group
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
rm -f $CONVERT_DIR/output.tf
cp $IMPORT_DIR/*tf $CONVERT_DIR
cp $TF_CONVERT/main.tf $CONVERT_DIR
cd $CONVERT_DIR
echo "[convert] copy done"

echo "[convert] mkdir"
for resource in role group user policy; do
    mkdir -p $resource;
done
echo "[convert] mkdir done"

echo "[convert] init"
terraform init


###### IAM POLICY #########
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
echo "[convert] iamp done"


###### IAM ROLE #########
echo "[convert] iamr mv tf"
if [ -f iamr.tf ]; then
    mv iamr.tf role
fi
echo "[convert] iamr mv tf done"

echo "[convert] iamr mv state"
for r in `terraform state list | grep '^aws_iam_role\.'`; do terraform state mv $r module.role.$r; done
rm -f terraform.tfstate.*.backup
echo "[convert] iamr mv state done"

echo "[convert] iamr create role/output.tf"
content=`terraform state list | grep '^module\.role\.aws_iam_role\.' | sed 's/module.role.\(.*\)/    \(\1.name\) = \1,/'`;
printf "output\"roles\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > role/output.tf
echo "[convert] iamr create role/output.tf done"
echo "[convert] iamr done"

###### IAM USER #########
echo "[convert] iamu mv tf"
if [ -f iamu.tf ]; then
    mv iamu.tf user
fi
echo "[convert] iamu mv tf done"

echo "[convert] iamu mv state"
for r in `terraform state list | grep '^aws_iam_user\.'`; do terraform state mv $r module.user.$r; done
rm -f terraform.tfstate.*.backup
echo "[convert] iamu mv state done"

echo "[convert] iamu create user/output.tf"
content=`terraform state list | grep '^module\.user\.aws_iam_user\.' | sed 's/module.user.\(.*\)/    \(\1.name\) = \1,/'`;
printf "output\"users\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > user/output.tf
echo "[convert] iamu create user/output.tf done"
echo "[convert] iamu done"

###### IAM GROUP #########
echo "[convert] iamg rm tf"
if [ -f iamg.tf ]; then
    rm iamg.tf
fi
echo "[convert] iamg rm tf done"

echo "[convert] iamg mv state"
for g in `terraform state list | grep '^aws_iam_group\.' | sed 's/aws_iam_group\.\(.*\)/\1/'`; do terraform state mv aws_iam_group.$g module.group.module.$g.aws_iam_group.group; done
rm -f terraform.tfstate.*.backup
echo "[convert] iamg mv state done"

tf=group/main.tf;
echo "[convert] create $tf"
rm -f $tf; for g in `terraform state list | grep 'aws_iam_group\.' | sed 's/^module\.group\.module\.\(.*\)\.aws_iam_group\..*/\1/'`; do printf "module\"$g\"{\nsource=\"$GROUP_MODULE_PATH\"\ngroup_name=\"$g\"\nuser_name_list=var.group_members[\"$g\"]\n}\n" >> $tf; done;
terraform fmt $tf
echo "[convert] create $tf done"

echo "[convert] iamg create group/output.tf"
content=`terraform state list | grep 'aws_iam_group\.' | sed 's/^module\.group\.module\.\(.*\)\.aws_iam_group\..*/"\1"=module.\1.group,/'`;
printf "output\"groups\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > group/output.tf
echo "[convert] iamg create group/output.tf done"
echo "[convert] iamg done"

##### IAM GROUP MEMBERSHIP ##########

echo "[convert] iamgm mv state"
for g in `terraform state list | grep '^aws_iam_group_membership\.' | sed 's/aws_iam_group_membership.\(.*\)/\1/'`; do terraform state mv aws_iam_group_membership.$g module.group.module.$g.aws_iam_group_membership.group_membership; done
rm -f terraform.tfstate.*
echo "[convert] iamgm mv state done"

echo "[convert] iamgm create group_membership.tf"
tf=group_membership.tf; rm -f $tf;
printf "module\"group\"{\nsource = \"./group\"\ngroup_members = {\n" >> $tf; for g in `grep aws_iam_group_membership iamgm.tf | sed 's/.*aws_iam_group_membership" "\(.*\)".*/\1/'`; do user_str=`grep -A 2 -e "aws_iam_group_membership\" \"$g\"" iamgm.tf | grep users | sed -e 's/.*users = \[\([^]]*\)\]/\1/' -e 's/\"//g' -e 's/,//g'`; printf "\"$g\"=[\n" >>$tf; for u in `printf "$user_str"`; do printf "module.user.users[\"$u\"].name,\n" >> $tf; done; printf "],\n" >> $tf; done; printf "}\n}\n" >> $tf
terraform fmt $tf
echo "[convert] iamgm create group_membership.tf done"
echo "[convert] copy group/variables.tf"
cp ../$TF_CONVERT/group_variables.tf group/variables.tf
echo "[convert] copy group/variables.tf done"

echo "[convert] rm iamgm.tf"
rm iamgm.tf
echo "[convert] rm iamgm.tf done"

cp ../$TF_CONVERT/output.tf .

terraform init
terraform plan
