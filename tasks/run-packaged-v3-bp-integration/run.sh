#!/bin/bash -l
set -o errexit
set -o pipefail

PACK_VERSION="$(cat pack/version)"
export PACK_VERSION

if [[ -d "release-artifacts" ]]; then
   echo ">>>>>>>>>>>>>>> Running with packaged CNB"
   BP_PACKAGED_PATH="$(realpath "$(find ./release-artifacts -name "*.tgz")")"
   export BP_PACKAGED_PATH
 fi

cd buildpack

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

echo "Start Docker"
../buildpacks-ci/scripts/start-docker > /dev/null

./scripts/integration.sh
