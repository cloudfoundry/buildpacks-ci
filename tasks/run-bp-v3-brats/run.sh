#!/bin/bash -l
set -o errexit
set -o pipefail

cd buildpack

export GOPATH=$PWD
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

./scripts/v3-brats.sh
