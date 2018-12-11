#!/bin/bash -l
set -o errexit
set -o pipefail

"./cf-space/login"
cd buildpack

if [ ! -f ./go.mod ]; then
    export GOPATH=$PWD
fi
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

if [ -f ./go.mod ]; then
    go mod download
fi
./scripts/brats.sh
