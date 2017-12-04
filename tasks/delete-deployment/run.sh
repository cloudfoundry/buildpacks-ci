#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd "bbl-state/$ENV_NAME"
  eval "$(bbl print-env)"
  bosh2 -n delete-deployment -d "${DEPLOYMENT_NAME}"
popd
