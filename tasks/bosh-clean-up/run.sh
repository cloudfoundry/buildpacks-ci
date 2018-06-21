#!/usr/bin/env bash

set -xeuo pipefail

pushd bbl-state/${ENV_NAME}
  set +x
  eval "$(bbl print-env)"
  set -x
  trap "pkill -f ssh" EXIT
popd

bosh2 clean-up -n --all
