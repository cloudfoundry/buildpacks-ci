#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

./buildpacks-ci/scripts/start-docker

docker load -i builder-image/builder.tgz

pushd pack
    go build -mod=vendor -o pack ./cmd/pack/main.go
popd

./pack/pack build node-app --builder "$BUILDER_REPO:$STACK" -p cnb-builder/fixtures/node_app
