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
for app_path in cnb-builder/fixtures/*; do
    ./pack/pack build "$(basename "$app_path")" --builder "$REPO:$STACK" -p "$app_path" --no-pull
done

PATH="$PATH":"$(pwd)"/pack
export PATH

export GOMAXPROCS=4

pushd buildpacks-ci/tasks/test-builder
    go test -args fixtures

    if [ "$STACK" == "cflinuxfs3" ]; then
	go test -args fs3-fixtures
    fi
popd
