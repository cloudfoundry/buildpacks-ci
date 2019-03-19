#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

"./cf-space/login"

cd repo

./scripts/integration.sh
