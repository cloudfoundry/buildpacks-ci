#!/bin/bash -l
set -o errexit
set -o pipefail

if [[ -d "release-artifacts" ]]; then
    BP_PACKAGED_PATH="$(realpath "$(find release-artifacts -name "*.tgz")")"
    export BP_PACKAGED_PATH
    echo "Buildpack is at: ${BP_PACKAGED_PATH}"
fi

PACK_PATH="$(realpath "$(find pack -name "*linux.tgz")")"
mkdir -p buildpack/.bin
tar xvf "${PACK_PATH}" -C buildpack/.bin > /dev/null

cd buildpack

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

echo "Start Docker"
../buildpacks-ci/scripts/start-docker > /dev/null

./scripts/integration.sh
