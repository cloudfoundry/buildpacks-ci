#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

#shellcheck source=../../scripts/start-docker
source ./buildpacks-ci/scripts/start-docker
util::docker::start
trap util::docker::stop EXIT

set -x

docker load -i builder-image/builder.tgz

echo "Running metabuildpack integration test"

repo="$(realpath repo)"
pushd "$repo"
  ./scripts/integration.sh
popd

