#!/bin/bash -l

set -x

pushd "bbl-state/$ENV_NAME"
  set +x
  eval "$(bbl print-env)"
  set -x
  trap "pkill -f ssh" EXIT
popd

bosh -d rootfs-smoke-test run-errand "$ENV_NAME-smoke-test"
