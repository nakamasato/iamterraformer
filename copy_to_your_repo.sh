#!/bin/bash

set -eu

while getopts d:m: OPT
do
    case $OPT in
        d)  target_dir=$OPTARG
            ;;
        m)  target_module_dir=$OPTARG
            ;;
        *)  echo "Usage: $0 [-d target_dir] [-m target_module_dir]" 1>&2
            exit 1
            ;;
    esac
done

TARGET_DIR=${target_dir}
TARGET_MODULE_DIR=${target_module_dir}
rm -rf $TARGET_DIR
rm -rf $TARGET_MODULE_DIR
mkdir -p $TARGET_DIR
mkdir -p $TARGET_MODULE_DIR
# copy to target dir
cp -r tf/modules/iam/ $TARGET_MODULE_DIR
cp -r converted/ $TARGET_DIR

# update module path
for r in group-membership group-policy-attachment role-policy-attachment user-policy-attachment; do
    relative_to_module=$(realpath --relative-to=$TARGET_DIR $TARGET_MODULE_DIR/$r)
    echo "../tf/modules/iam/$r -> $relative_to_module"
    sed -i.bak "s#../tf/modules/iam/$r#$relative_to_module#g" $TARGET_DIR/$r.tf
done
rm $TARGET_DIR/*.tf.bak
cp converted/backend.tf $TARGET_DIR

