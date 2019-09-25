#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

cd repo

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

if [[ "${RUN_UNPRIVILEGED}" == "true" ]]; then
  chpst -u testuser:testuser ./scripts/unit.sh
else
  ./scripts/unit.sh
fi
