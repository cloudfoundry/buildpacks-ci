#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

SUFFIX="${ROOTFS_SUFFIX-}"

cp "receipt-s3/${STACK}_receipt${SUFFIX}"-* "rootfs/${STACK}/${STACK}_receipt"

pushd rootfs
    version=$(cat ../version/number)
    git add "${STACK}/${STACK}_receipt"

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
