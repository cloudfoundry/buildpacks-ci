#!/bin/bash -l

set -euo pipefail

"./cf-space/login"

pushd plugin
  ./scripts/all-tests.sh
popd
