#!/bin/bash -l
set -o errexit
set -o pipefail

cd buildpack

export GOPATH=$PWD
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

echo "Start Docker"
../buildpacks-ci/scripts/start-docker > /dev/null

echo "Pulling build image"
docker pull cfbuildpacks/bpv3:build

./scripts/v3-brats.sh
