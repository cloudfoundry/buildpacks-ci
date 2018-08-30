#!/bin/bash -l
set -o errexit
set -o pipefail

cf_flag=""

if [ -n "$CF_STACK" ]; then
    cf_flag="-$CF_STACK"
fi

"./cf-space$cf_flag/login"
cd buildpack

export GOPATH=$PWD
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

./scripts/brats.sh
