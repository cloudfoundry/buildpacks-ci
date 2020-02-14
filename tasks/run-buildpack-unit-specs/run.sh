#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

cd buildpack

if [[ ${DOCKER_START} == "true" ]]; then
  echo "Start Docker"
  #shellcheck source=../../scripts/start-docker
  source ../buildpacks-ci/scripts/start-docker
  util::docker::start
  trap util::docker::stop EXIT
fi

./scripts/unit.sh
