#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

"./cf-space/login"

set -x

SPACE=$(cat cf-space/name)
cf delete-space -f "$SPACE" || true
