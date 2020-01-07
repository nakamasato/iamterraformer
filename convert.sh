#!/bin/bash

set -ue

FORCE=false
GROUP_MEMBERSHIP_MODULE_PATH=../tf/modules/iam/group-membership
GROUP_POLICY_ATTACHMENT_MODULE_PATH=../tf/modules/iam/group-policy-attachment
USER_POLICY_ATTACHMENT_MODULE_PATH=../tf/modules/iam/user-policy-attachment
ROLE_POLICY_ATTACHMENT_MODULE_PATH=../tf/modules/iam/role-policy-attachment

IMPORT_DIR=imported
CONVERT_DIR=converted
TF_COMMON=tf/common
TF_CONVERT=tf/convert
TF_STATE=iam.tfstate

while getopts 'f' c
do
  case $c in
    f) FORCE=true ;;
  esac
done

if $FORCE; then
   rm -rf $CONVERT_DIR
fi
mkdir -p $CONVERT_DIR
if [ ! -f $TF_STATE -o $FORCE ]; then
    cp $IMPORT_DIR/$TF_STATE $CONVERT_DIR
fi
echo "[convert] copy"
rm -f $CONVERT_DIR/output.tf
rm -f $CONVERT_DIR/group_policy_attachment.tf
rm -f $CONVERT_DIR/role_policy_attachment.tf
rm -f $CONVERT_DIR/user_policy_attachment.tf
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
    mv iamp.tf policy/main.tf
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
    mv iamr.tf role/main.tf
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
    mv iamu.tf user/main.tf
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
echo "[convert] iamg mv tf"
if [ -f iamg.tf ]; then
    mv iamg.tf group/main.tf
fi
echo "[convert] iamg mv tf done"

echo "[convert] iamg mv state"
for r in `terraform state list | grep '^aws_iam_group\.'`; do terraform state mv $r module.group.$r; done
rm -f terraform.tfstate.*.backup
echo "[convert] iamg mv state done"

echo "[convert] iamg create group/output.tf"
content=`terraform state list | grep '^module\.group\.aws_iam_group\.' | sed 's/module.group.\(.*\)/    \(\1.name\) = \1,/'`;
printf "output\"groups\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > group/output.tf
echo "[convert] iamg create group/output.tf done"
echo "[convert] iamg done"

##### IAM GROUP MEMBERSHIP ##########

echo "[convert] iamgm mv state"
for g in `terraform state list | grep '^aws_iam_group_membership\.' | sed 's/aws_iam_group_membership.\(.*\)/\1/'`; do terraform state mv aws_iam_group_membership.$g module.group-membership.aws_iam_group_membership.group-membership[\"$g\"]; done
rm -f terraform.tfstate.*
echo "[convert] iamgm mv state done"

echo "[convert] iamgm create group_membership.tf"
tf=group_membership.tf; rm -f $tf;
printf "module \"group-membership\"{\nsource=\"$GROUP_MEMBERSHIP_MODULE_PATH\"\ngroup_memberships = {\n" >> $tf

for g in `grep aws_iam_group_membership iamgm.tf | sed 's/.*aws_iam_group_membership" "\(.*\)".*/\1/'`; do user_str=`grep -A 2 -e "aws_iam_group_membership\" \"$g\"" iamgm.tf | grep users | sed -e 's/.*users = \[\([^]]*\)\]/\1/' -e 's/\"//g' -e 's/,//g'`; printf "\"$g\"=[\n" >>$tf; for u in `printf "$user_str"`; do printf "module.user.users[\"$u\"].name,\n" >> $tf; done; printf "],\n" >> $tf; done; printf "}\n}\n" >> $tf
terraform fmt $tf
echo "[convert] iamgm create group_membership.tf done"

echo "[convert] rm iamgm.tf"
rm iamgm.tf
echo "[convert] rm iamgm.tf done"

##### IAM GROUP POLICY ATTACHMENT ########
resource=iamgpa
echo "[convert] $resource mv state"
for a in `terraform state list | grep '^aws_iam_group_policy_attachment\.' | sed 's/aws_iam_group_policy_attachment\.//'`; do terraform state mv aws_iam_group_policy_attachment.$a module.group-policy-attachment.aws_iam_group_policy_attachment.attachment[\"$a\"]; done
rm -f terraform.tfstate.*
echo "[convert] $resource mv state done"

tf=group_policy_attachment.tf; rm -rf $tf;
echo "[convert] create $tf"
printf "module \"group-policy-attachment\"{\nsource=\"$GROUP_POLICY_ATTACHMENT_MODULE_PATH\"\ngroup_policy_pairs=[\n" >> $tf
# AWS Managed Policy
for a in `grep -B1 arn:aws:iam::aws:policy $resource.tf | grep aws_iam_group_policy_attachment | sed 's/.*aws_iam_group_policy_attachment" "\(.*\)".*/\1/'`; do
    grep -A 2 $a $resource.tf | awk -F'\n' '{if(NR == 1) {printf $0} else {printf ","$0}}' | sed 's/.*aws_iam_group_policy_attachment" "\(.*\)".*policy_arn = "\(.*\)".*group.*= "\(.*\)"/{ group_name = module.group.groups[\"\3\"].name, policy_arn = \"\2\", name = \"\1\" },/' >> $tf
done
# Custom Policy
for a in `grep -B1 -E 'arn:aws:iam::[0-9]+:policy' $resource.tf | grep aws_iam_group_policy_attachment | sed 's/.*aws_iam_group_policy_attachment" "\(.*\)".*/\1/'`; do
    grep -A 2 $a $resource.tf | awk -F'\n' '{if(NR == 1) {printf $0} else {printf ","$0}}' |  sed 's/.*aws_iam_group_policy_attachment" "\(.*\)".*policy_arn = .*"arn:aws:iam::.*:policy.*\/\(.*\)".*group.* = "\(.*\)"/{ group_name = module.group.groups[\"\3\"].name, policy_arn = module.policy.policies[\"\2\"].arn, name = \"\1\" },/' >> $tf
done
printf "]\n" >> $tf
printf "}\n" >> $tf
terraform fmt $tf
echo "[convert] create $tf done"

echo "[convert] rm $resource.tf"
rm $resource.tf
echo "[convert] rm $resource.tf done"

##### IAM ROLE POLICY ATTACHMENT ########
resource=iamrpa
echo "[convert] $resource mv state"
for a in `terraform state list | grep '^aws_iam_role_policy_attachment\.' | sed 's/aws_iam_role_policy_attachment\.//'`; do
    terraform state mv aws_iam_role_policy_attachment.$a module.role-policy-attachment.aws_iam_role_policy_attachment.attachment[\"$a\"]
done
rm -f terraform.tfstate.*
echo "[convert] $resource mv state done"

tf=role_policy_attachment.tf; rm -rf $tf;
echo "[convert] create $tf"
printf "module \"role-policy-attachment\"{\nsource=\"$ROLE_POLICY_ATTACHMENT_MODULE_PATH\"\nrole_policy_pairs=[\n" >> $tf
# AWS Managed Policy
for a in `grep -B1 arn:aws:iam::aws:policy $resource.tf | grep aws_iam_role_policy_attachment | sed 's/.*aws_iam_role_policy_attachment" "\(.*\)".*/\1/'`; do
    grep -A 2 $a $resource.tf | awk -F'\n' '{if(NR == 1) {printf $0} else {printf ","$0}}' | sed 's/.*aws_iam_role_policy_attachment" "\(.*\)".*policy_arn = "\(.*\)".*role.*= "\(.*\)"/{ role_name = module.role.roles[\"\3\"].name, policy_arn = \"\2\", name = \"\1\" },/' >> $tf
done
# Custom Policy
for a in `grep -B1 -E 'arn:aws:iam::[0-9]+:policy' $resource.tf | grep aws_iam_role_policy_attachment | sed 's/.*aws_iam_role_policy_attachment" "\(.*\)".*/\1/'`; do
    grep -A 2 $a $resource.tf | awk -F'\n' '{if(NR == 1) {printf $0} else {printf ","$0}}' |  sed 's/.*aws_iam_role_policy_attachment" "\(.*\)".*policy_arn = .*"arn:aws:iam::.*:policy.*\/\(.*\)".*role.* = "\(.*\)"/{ role_name = module.role.roles[\"\3\"].name, policy_arn = module.policy.policies[\"\2\"].arn, name = \"\1\" },/' >> $tf
done
printf "]\n" >> $tf
printf "}\n" >> $tf
terraform fmt $tf
echo "[convert] create $tf done"

echo "[convert] rm $resource.tf"
rm $resource.tf
echo "[convert] rm $resource.tf done"

##### IAM USER POLICY ATTACHMENT ########
resource=iamupa
echo "[convert] $resource mv state"
for a in `terraform state list | grep '^aws_iam_user_policy_attachment\.' | sed 's/aws_iam_user_policy_attachment\.//'`; do
    terraform state mv aws_iam_user_policy_attachment.$a module.user-policy-attachment.aws_iam_user_policy_attachment.attachment[\"$a\"]
done
rm -f terraform.tfstate.*
echo "[convert] $resource mv state done"

tf=user_policy_attachment.tf; rm -rf $tf;
echo "[convert] create $tf"
printf "module \"user-policy-attachment\"{\nsource=\"$USER_POLICY_ATTACHMENT_MODULE_PATH\"\nuser_policy_pairs=[\n" >> $tf
# AWS Managed Policy
for a in `grep -B1 arn:aws:iam::aws:policy $resource.tf | grep aws_iam_user_policy_attachment | sed 's/.*aws_iam_user_policy_attachment" "\(.*\)".*/\1/'`; do
    grep -A 2 $a $resource.tf | awk -F'\n' '{if(NR == 1) {printf $0} else {printf ","$0}}' | sed 's/.*aws_iam_user_policy_attachment" "\(.*\)".*policy_arn = "\(.*\)".*user.*= "\(.*\)"/{ user_name = module.user.users[\"\3\"].name, policy_arn = \"\2\", name = \"\1\" },/' >> $tf
done
# Custom Policy
for a in `grep -B1 -E 'arn:aws:iam::[0-9]+:policy' $resource.tf | grep aws_iam_user_policy_attachment | sed 's/.*aws_iam_user_policy_attachment" "\(.*\)".*/\1/'`; do
    grep -A 2 $a $resource.tf | awk -F'\n' '{if(NR == 1) {printf $0} else {printf ","$0}}' |  sed 's/.*aws_iam_user_policy_attachment" "\(.*\)".*policy_arn = .*"arn:aws:iam::.*:policy.*\/\(.*\)".*user.* = "\(.*\)"/{ user_name = module.user.users[\"\3\"].name, policy_arn = module.policy.policies[\"\2\"].arn, name = \"\1\" },/' >> $tf
done
printf "]\n" >> $tf
printf "}\n" >> $tf
terraform fmt $tf
echo "[convert] create $tf done"

echo "[convert] rm $resource.tf"
rm $resource.tf
echo "[convert] rm $resource.tf done"

cp ../$TF_CONVERT/output.tf .

terraform fmt -recursive

terraform init
terraform plan
