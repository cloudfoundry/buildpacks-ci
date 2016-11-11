#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd deployments-buildpacks
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  bundle install
  # shellcheck disable=SC1091
  . ./bin/target_bosh "$DEPLOYMENT_NAME"
popd

bosh -d "deployments-buildpacks/deployments/$DEPLOYMENT_NAME/rootfs-smoke-test.yml" run errand cflinuxfs2-smoke-test
