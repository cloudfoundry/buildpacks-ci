#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

receipt_file="receipt.${STACK}.x86_64"

cp "receipt-s3/${receipt_file}"-* "rootfs/${receipt_file}"

pushd rootfs
    version=$(cat ../version/number)
    git add "${receipt_file}"

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
