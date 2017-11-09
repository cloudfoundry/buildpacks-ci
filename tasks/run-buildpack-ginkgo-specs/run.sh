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

echo "Start Docker"
../buildpacks-ci/scripts/start-docker >/dev/null

./scripts/integration.sh
