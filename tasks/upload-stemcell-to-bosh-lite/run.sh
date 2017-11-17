#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd "bbl-state/${ENV_NAME}"
  eval "$(bbl print-env)"
popd

bosh2 upload-stemcell https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent
