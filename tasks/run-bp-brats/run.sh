#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

./cf-space/login
cd buildpack

export GOPATH=$PWD
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

./scripts/unit.sh
./scripts/brats.sh
