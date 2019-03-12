#!/bin/bash -l

set -euo pipefail

"./cf-space/login"

pushd stack-auditor
  ./scripts/all-tests.sh
popd
