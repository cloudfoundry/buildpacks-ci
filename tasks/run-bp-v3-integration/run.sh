#!/bin/bash -l
set -o errexit
set -o pipefail

PACK_VERSION="$(cat pack/version)"
export PACK_VERSION

cd buildpack

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

echo "Start Docker"
../buildpacks-ci/scripts/start-docker > /dev/null

./scripts/integration.sh
