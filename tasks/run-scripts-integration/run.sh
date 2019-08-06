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
  ../buildpacks-ci/scripts/start-docker >/dev/null
fi

./scripts/integration.sh
