#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

SUFFIX="${STACKS_SUFFIX-}"

buildpacks-ci/scripts/start-docker

pushd cflinuxfs3
  make

  versioned_stack_filename="../cflinuxfs3-artifacts/cflinuxfs3$SUFFIX-$(cat ../version/number).tar.gz"
  mv cflinuxfs3.tar.gz "$versioned_stack_filename"

  versioned_receipt_filename="../receipt-artifacts/cflinuxfs3_receipt$SUFFIX-$(cat ../version/number)"
  echo "Rootfs SHASUM: $(sha1sum "$versioned_stack_filename" | awk '{print $1}')" > "$versioned_receipt_filename"
  echo "" >> "$versioned_receipt_filename"
  cat cflinuxfs3/cflinuxfs3_dpkg_l.out >> "$versioned_receipt_filename"

  which git
  TERM=xterm-color git --no-pager diff cflinuxfs3/cflinuxfs3_receipt "$versioned_receipt_filename" || true
popd
