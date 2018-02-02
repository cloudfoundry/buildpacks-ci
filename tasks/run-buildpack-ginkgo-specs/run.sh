#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

./cf-space/login
cd buildpack

export GOPATH=$PWD
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

# for the PHP buildpack
if [ -e run_tests.sh ]; then
  export TMPDIR
  TMPDIR=$(mktemp -d)
  pip install -r requirements.txt
fi

./scripts/unit.sh

if [[ -z ${SKIP_DOCKER_START:-} ]]; then
  echo "Start Docker"
  ../buildpacks-ci/scripts/start-docker >/dev/null
fi

./scripts/integration.sh
