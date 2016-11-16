#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd deployments-buildpacks
  bundle install --jobs="$(nproc)"
  # shellcheck disable=SC1091
  source ./bin/target_bosh "$DEPLOYMENT_NAME"
popd

pushd cflinuxfs2-rootfs-release
  ./scripts/generate-bosh-lite-manifest
  cp manifests/bosh-lite/rootfs-smoke-test.yml "../deployments-buildpacks/deployments/$DEPLOYMENT_NAME/"
popd

pushd deployments-buildpacks
  git add .
  git commit -m "create rootfs with smoke test deployment manifest for $DEPLOYMENT_NAME"
popd

rsync -a deployments-buildpacks/ rootfs-smoke-test-manifest-artifacts
