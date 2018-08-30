#!/bin/bash -l

set -o errexit
set -o pipefail

cf_flag=""

if [ -n "$CF_STACK" ]; then
    cf_flag="-$CF_STACK"
fi

"./cf-space$cf_flag/login"

set -x

SPACE=$(cat cf-space"$cf_flag"/name)
cf delete-space -f "$SPACE" || true
