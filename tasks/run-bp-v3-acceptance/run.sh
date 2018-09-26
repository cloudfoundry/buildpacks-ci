#!/bin/bash -l
set -o errexit
set -o pipefail

cd buildpack

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

echo "Start Docker"
../buildpacks-ci/scripts/start-docker > /dev/null

./scripts/acceptance.sh
