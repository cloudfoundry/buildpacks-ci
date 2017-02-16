#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

./cf-space/login
SPACE=$(cat cf-space/name)
cf delete-space -f "$SPACE"
