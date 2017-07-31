#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

./buildpacks-ci/scripts/start-docker

cd buildpack

export GOPATH=$PWD
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

./scripts/unit.sh

CACHED=true  ./scripts/integration.sh
CACHED=false ./scripts/integration.sh
