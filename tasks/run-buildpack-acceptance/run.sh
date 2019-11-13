#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

readonly ROOT="${PWD}"

function main() {
  "./cf-space/login"

  if [[ -z ${SKIP_DOCKER_START:-} ]]; then
    echo "Start Docker"
    ../buildpacks-ci/scripts/start-docker >/dev/null
  fi

  artifact_path="${ROOT}/catndidate/candidate.zip"

  pushd buildpack-acceptance
    ./scripts/integration.sh --language $LANGUAGE --buildpack "${artifact_path}" --buildpack-version $VERSION 
  popd

}
