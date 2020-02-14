#!/bin/bash -l
set -o errexit
set -o pipefail

#shellcheck source=../../scripts/start-docker
source ./buildpacks-ci/scripts/start-docker
util::docker::start
trap util::docker::stop EXIT

PACK_PATH="$(realpath "$(find pack -name "*linux.tgz")")"
mkdir -p buildpack/.bin
tar xvf "${PACK_PATH}" -C buildpack/.bin > /dev/null

cd buildpack

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

./scripts/integration.sh
