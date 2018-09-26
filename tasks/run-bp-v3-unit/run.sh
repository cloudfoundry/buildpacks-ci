#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

cd buildpack

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

./scripts/unit.sh
