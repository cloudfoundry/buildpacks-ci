#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

if [[ -e "${PWD}/buildpack/scripts/.util/tools.sh" ]]; then
  source "${PWD}/buildpack/scripts/.util/tools.sh"
  util::tools::cf::install --directory "${PWD}/buildpack/.bin"
fi

cd buildpack

echo "Starting Docker daemon for Switchblade platform tests"
source ../buildpacks-ci/scripts/start-docker
util::docker::start
trap util::docker::stop EXIT

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN is required for Switchblade tests"
  exit 1
fi

INTEGRATION_ARGS=(
  "--platform" "docker"
  "--github-token" "${GITHUB_TOKEN}"
)

if [[ -n "${CF_STACK:-}" ]]; then
  echo "Running Switchblade Docker tests for stack: ${CF_STACK}"
else
  echo "Running Switchblade Docker tests (no stack specified, using buildpack default)"
fi

./scripts/integration.sh "${INTEGRATION_ARGS[@]}"
