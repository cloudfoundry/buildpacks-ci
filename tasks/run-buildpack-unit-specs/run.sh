#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

cd buildpack

if [[ ${DOCKER_START} == "true" ]]; then
  echo "Start Docker"
  ../buildpacks-ci/scripts/start-docker >/dev/null
fi

./scripts/unit.sh
