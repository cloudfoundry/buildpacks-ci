#!/bin/bash -l
set -o errexit
set -o pipefail

export PACK_VERSION="$(cat pack/version)"

cd buildpack

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

echo "Start Docker"
../buildpacks-ci/scripts/start-docker > /dev/null

./scripts/integration.sh
