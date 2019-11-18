#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

./buildpacks-ci/scripts/start-docker

set -x

docker pull "$RUN_IMAGE"
BUILDER="$(realpath "$(find builder-image -name "*\.t*")")"
docker load -i "$BUILDER"

pushd pack
    echo "Unpacking pack..."
    PACK_FILE="$(realpath "$(find . -name "*-linux.tgz")")"
    tar xvf "$PACK_FILE" pack -C ./
popd

echo "Building test apps..."

PATH="$PATH":"$(pwd)"/pack
fixtures="$(realpath cnb-builder/fixtures)"
fs3fixtures="$(realpath cnb-builder/fs3-fixtures)"
tinyfixtures="$(realpath cnb-builder/tiny-fixtures)"
export PATH

export GOMAXPROCS=4

pushd buildpacks-ci/tasks/test-builder
    go test -args "$tinyfixtures" -v

    if [ "$STACK" == "bionic" ]; then
    	go test -args "$fixtures" -v
    fi

    if [ "$STACK" == "cflinuxfs3" ]; then
    	go test -args "$fixtures" -v
	    go test -args "$fs3fixtures" -v
    fi
popd
