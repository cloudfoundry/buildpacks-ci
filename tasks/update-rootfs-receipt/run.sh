#!/bin/bash

set -e

SUFFIX="${ROOTFS_SUFFIX-}"

cp receipt-s3/cflinuxfs2_receipt$SUFFIX-* stacks/cflinuxfs2/cflinuxfs2_receipt

pushd stacks
    version=`cat ../version/number`
    git add cflinuxfs2/cflinuxfs2_receipt

    set +e
      diff=$(git diff --cached --exit-code)
      no_changes=$?
    set -e

    if [ $no_changes -ne 0 ]
    then
      git commit -m "Commit receipt for $version"
    else
      echo "No new changes to rootfs or receipt"
    fi
popd

rsync -a stacks/ new-stack-commit
