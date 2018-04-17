#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

buildpacks-ci/scripts/start-docker

pushd rootfs
  make

  versioned_stack_filename="../rootfs-artifacts/$STACK-$(cat ../version/number).tar.gz"
  mv "$STACK.tar.gz" "$versioned_stack_filename"

  versioned_receipt_filename="../receipt-artifacts/${STACK}_receipt-$(cat ../version/number)"
  echo "Rootfs SHASUM: $(sha1sum "$versioned_stack_filename" | awk '{print $1}')" > "$versioned_receipt_filename"
  echo "" >> "$versioned_receipt_filename"
  cat "$STACK/${STACK}_dpkg_l.out" >> "$versioned_receipt_filename"

  which git
  TERM=xterm-color git --no-pager diff "$STACK/${STACK}_receipt" "$versioned_receipt_filename" || true
popd
