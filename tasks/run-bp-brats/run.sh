#!/bin/bash -l
set -o errexit
set -o pipefail

"./cf-space/login"
cd buildpack

export GOPATH=$PWD
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

./scripts/brats.sh
