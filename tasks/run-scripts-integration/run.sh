#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

"./cf-space/login"

if [[ -d "candidate" ]]; then
    BUILDPACK_FILE="$(realpath "$(find candidate -name "*.zip")")"
    export BUILDPACK_FILE
    echo "Buildpack is at: ${BUILDPACK_FILE}"
fi

cd repo

if [[ -z ${SKIP_DOCKER_START:-} ]]; then
  echo "Start Docker"
  #shellcheck source=../../scripts/start-docker
  source ../buildpacks-ci/scripts/start-docker
  util::docker::start
  trap util::docker::stop EXIT
fi

./scripts/integration.sh
