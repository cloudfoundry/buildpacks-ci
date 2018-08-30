#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

cf_flag=""

if [ -n "$CF_STACK" ]; then
    cf_flag="-$CF_STACK"
fi

"./cf-space$cf_flag/login"

cd buildpack

export GOPATH=$PWD
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

if [[ -z ${SKIP_DOCKER_START:-} ]]; then
  echo "Start Docker"
  ../buildpacks-ci/scripts/start-docker >/dev/null
fi

./scripts/integration.sh
