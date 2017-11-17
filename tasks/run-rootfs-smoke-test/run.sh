#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd "bbl-state/$ENV_NAME"
  eval "$(bbl print-env)"
popd

bosh2 -d rootfs-smoke-test run-errand cflinuxfs2-smoke-test
