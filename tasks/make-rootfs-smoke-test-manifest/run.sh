#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd buildpacks-ci
  # shellcheck disable=SC1091
  source ./bin/target_bosh "$DEPLOYMENT_NAME"
popd

MANIFEST_DIR="rootfs-smoke-test-manifest-artifacts/$DEPLOYMENT_NAME"
mkdir -p "$MANIFEST_DIR"

pushd cflinuxfs2-rootfs-release
  ./scripts/generate-bosh-lite-manifest
popd

cp cflinuxfs2-rootfs-release/manifests/bosh-lite/rootfs-smoke-test.yml "$MANIFEST_DIR/"
