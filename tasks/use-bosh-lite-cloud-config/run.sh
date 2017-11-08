#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

pushd bbl-state/"${ENV_NAME}"
  eval "$(bbl print-env)"
  bosh2 env
popd

bosh2 update-cloud-config -n cf-deployment/iaas-support/bosh-lite/cloud-config.yml

