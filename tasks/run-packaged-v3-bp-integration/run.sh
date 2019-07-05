#!/bin/bash -l
set -o errexit
set -o pipefail

#PACK_VERSION="$(cat pack/version)"
#export PACK_VERSION

if [[ -d "release-artifacts" ]]; then
    BP_PACKAGED_PATH="$(realpath "$(find release-artifacts -name "*.tgz")")"
    export BP_PACKAGED_PATH
    echo "${BP_PACKAGED_PATH}"
fi

PACK_PATH="$(realpath "$(find pack -name "*.tar.gz")")"
mkdir -p pack_source
tar xvf $PACK_PATH -C pack_source
pushd pack_source
    echo "Building pack..."
    go build -o ../buildpack/.bin/pack ./cmd/pack/main.go
popd

cd buildpack

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

echo "Start Docker"
../buildpacks-ci/scripts/start-docker > /dev/null

./scripts/integration.sh
