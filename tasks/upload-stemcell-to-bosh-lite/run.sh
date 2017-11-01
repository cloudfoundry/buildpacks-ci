#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd buildpacks-ci
  # shellcheck disable=SC1091
  source ./bin/target_bosh "$DEPLOYMENT_NAME"
popd

bosh upload stemcell https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent
