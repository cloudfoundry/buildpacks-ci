#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

cd repo

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

./scripts/unit.sh
