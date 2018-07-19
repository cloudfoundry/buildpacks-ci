#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=SC2086
if [ $STACK == 'cflinuxfs2' ]; then
    receipt_file="${STACK}_receipt"
    receipt_dest="${STACK}/${STACK}_receipt"
else
    receipt_file="receipt.${STACK}.x86_64"
    receipt_dest="receipt.${STACK}.x86_64"
fi

cp "receipt-s3/${receipt_file}"-* "rootfs/${receipt_dest}"

pushd rootfs
    version=$(cat ../version/number)
    git add "${receipt_dest}"

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
