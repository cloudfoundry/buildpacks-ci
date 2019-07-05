#!/bin/bash -l
set -o errexit
set -o pipefail

#PACK_VERSION="$(cat pack/version)"
#export PACK_VERSION

if [[ -d "release-artifacts" ]]; then
    export BP_PACKAGED_PATH="$(realpath "$(find release-artifacts -name "*.tgz")")"
    echo "${BP_PACKAGED_PATH}"
fi

PACK_PATH="$(realpath "$(find pack -name "*linux.tgz")")"
mkdir -p buildpack/.bin
tar xvf ${PACK_PATH} -C buildpack/.bin

cd buildpack

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

echo "Start Docker"
../buildpacks-ci/scripts/start-docker > /dev/null

./scripts/integration.sh
