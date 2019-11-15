#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

config_filepath="$(realpath repo/integration/config.json)"

pushd buildpacks-ci/tasks/set-test-configuration
  go run -mod=vendor main.go "$config_filepath" "$STACK"
popd
