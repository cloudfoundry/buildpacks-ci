#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

./buildpacks-ci/scripts/start-docker

cd buildpack

./scripts/unit.sh

CACHED=true  ./scripts/integration.sh
CACHED=false ./scripts/integration.sh
