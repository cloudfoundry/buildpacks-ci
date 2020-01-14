#!/bin/bash -l
set -o errexit
set -o pipefail

PACK_PATH="$(realpath "$(find pack -name "*linux.tgz")")"
mkdir -p buildpack/.bin
tar xvf "${PACK_PATH}" -C buildpack/.bin > /dev/null

cd buildpack

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

echo "Start Docker"
../buildpacks-ci/scripts/start-docker

./scripts/integration.sh
