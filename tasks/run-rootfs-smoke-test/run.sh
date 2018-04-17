#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd "bbl-state/$ENV_NAME"
  set +x
  eval "$(bbl print-env)"
  set -x
  trap "pkill -f ssh" EXIT
popd

bosh2 -d rootfs-smoke-test run-errand "$ENV_NAME-smoke-test"
