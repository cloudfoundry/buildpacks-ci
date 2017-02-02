#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd deployments-buildpacks
  # shellcheck disable=SC1091
  . ./bin/target_bosh "$DEPLOYMENT_NAME"
popd

bosh -d "rootfs-smoke-test-manifest-artifacts/deployments/$DEPLOYMENT_NAME/rootfs-smoke-test.yml" run errand cflinuxfs2-smoke-test
