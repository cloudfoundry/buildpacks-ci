#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

./buildpacks-ci/scripts/start-docker

set -x

docker load -i builder-image/builder.tgz

echo "Running metabuildpack integration test"

repo="$(realpath repo)"
pushd "$repo"
  ./scripts/integration.sh
popd

