#!/bin/bash

set -eu
set -o pipefail

readonly ROOT="${PWD}"

function main() {
  #shellcheck source=../../scripts/start-docker
  source "${ROOT}/buildpacks-ci/scripts/start-docker"
  util::docker::start
  trap util::docker::stop EXIT

  "${ROOT}/buildpacks-ci/tasks/create-builder/run.rb"
}

main
