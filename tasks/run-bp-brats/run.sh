#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

"./cf-space-$CF_STACK/login"
cd buildpack

export GOPATH=$PWD
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

./scripts/brats.sh
