#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

cp receipt-s3/${ROOTFS}_receipt-* rootfs/${ROOTFS}/${ROOTFS}_receipt

pushd rootfs
    version=$(cat ../version/number)
    git add ${ROOTFS}/${ROOTFS}_receipt

    set +e
      git diff --cached --exit-code
      no_changes=$?
    set -e

    if [ $no_changes -ne 0 ]
    then
      git commit -m "Commit receipt for $version"
    else
      echo "No new changes to rootfs or receipt"
    fi
popd

rsync -a rootfs/ new-rootfs-commit
