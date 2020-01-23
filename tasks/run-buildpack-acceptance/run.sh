#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail
set -x

readonly ROOT="${PWD}"

function main() {
  "./cf-space/login"

  if [[ -z ${SKIP_DOCKER_START:-} ]]; then
    echo "Start Docker"
    "${ROOT}/buildpacks-ci/scripts/start-docker" >/dev/null
  fi

  local artifact_path version cached_flag
  artifact_path="$(find "${ROOT}/candidate" -name "*.zip" | head -1)"
  version="$( cut -d '-' -f 1 version/version )"
  cached_flag=""

  if [[ ${CACHED} == "true" ]]; then
    cached_flag="--cached"
  fi

  pushd buildpack-acceptance-tests
    ./scripts/integration.sh \
      --language "${LANGUAGE}" \
      --buildpack "${artifact_path}" \
      --buildpack-version "${version}" \
      "${cached_flag}"

  popd
}

main
