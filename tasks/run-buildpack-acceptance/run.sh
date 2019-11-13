#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail
set -x

readonly ROOT="${PWD}"

function main() {
  "./cf-space/login"

  # if [[ -z ${SKIP_DOCKER_START:-} ]]; then
  #   echo "Start Docker"
  #   ../buildpacks-ci/scripts/start-docker >/dev/null
  # fi

  local artifact_path version
  version="$( cut -d '-' -f 1 version/version )"

  # shellcheck disable=SC2086
  artifact_path="$(ls ${ROOT}/candidate/*.zip | head -1)"

  pushd buildpack-acceptance-tests
    ./scripts/integration.sh \
      --language "${LANGUAGE}" \
      --buildpack "${artifact_path}" \
      --buildpack-version "${version}"
  popd
}

main
