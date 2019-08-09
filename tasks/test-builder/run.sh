#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

./buildpacks-ci/scripts/start-docker

set -x

docker pull "$RUN_IMAGE"
docker load -i builder-image/builder.tgz

pushd pack
    echo "Building pack..."
    go build -mod=vendor -o pack ./cmd/pack/main.go
popd

echo "Building test apps..."

PATH="$PATH":"$(pwd)"/pack
fixtures="$(realpath cnb-builder/fixtures)"
fs3fixtures="$(realpath cnb-builder/fs3-fixtures)"
export PATH

export GOMAXPROCS=4

pushd buildpacks-ci/tasks/test-builder
    go test -args "$fixtures"

    if [ "$STACK" == "cflinuxfs3" ]; then
	go test -args "$fs3fixtures"
    fi
popd
