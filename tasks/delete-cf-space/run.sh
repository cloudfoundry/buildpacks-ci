#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

"./cf-space-$CF_STACK/login"
SPACE="$(cat cf-space-$CF_STACK/name)"
cf delete-space -f "$SPACE" || true
