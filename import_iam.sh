#!/bin/bash

set -ue

FORCE=false
# REPLACE_DOLLAR_REGEX=s/[^$][$]{aws:username}/\1\$\${aws:username}/g
REPLACE_DOLLAR_REGEX=s/\${aws:username}/\$\${aws:username}/g # not idempotent
while getopts 'f' c
do
  case $c in
    f) FORCE=true ;;
  esac
done
echo "[prepare] clean up"
if $FORCE; then rm -f iam*.tf{,state}; fi
echo "[prepare] install practice_terraforming"
gem install practice_terraforming -v 0.1.10
gem install terraforming -v 0.18.0
gem list terraforming

echo "[prepare] make a directory"
for env in dev; do for resource in role group user policy; do mkdir -p $env/$resource; done; done
tree
echo "[prepare] done"

tfstate=iam.tfstate
for resource in iamp iamu iamg iamgm iamr iamupa iamgpa iamrpa; do
    tf=$resource.tf
    if $FORCE; then rm -f $tf{,.bak}; fi

    if [ $resource = iamp -o $resource = iamg -o $resource = iamgm ];then
        terraforming=terraforming
    else
        terraforming=practice_terraforming
    fi
    if [ -f $tf ];then
        echo "[import] already imported ($tf and $tf)"
    else
        echo "[import] $resource"
        SECONDS=0
        if [ -f $tfstate ]; then
            tmp_file=tfstate.tmp
            $terraforming $resource --tfstate --merge $tfstate > $tmp_file
            mv $tmp_file $tfstate
        else
            $terraforming $resource --tfstate > $tfstate
        fi
        $terraforming $resource > $tf
        sed -i.bak $REPLACE_DOLLAR_REGEX $tf
        rm -f $tf.bak
        duration=$SECONDS
        echo "[import] $resource done ($(($duration / 60)) min $(($duration % 60)) sec)"
    fi
done

sed -i.bak $REPLACE_DOLLAR_REGEX $tfstate
rm -f $tfstate.bak

echo "[terraform] consistency check"
terraform init
terraform plan > plan_result.txt
echo "[terraform] completed consistency check"

