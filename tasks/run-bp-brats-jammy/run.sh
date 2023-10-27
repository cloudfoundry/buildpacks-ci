#!/bin/bash -l

set -o errexit
set -o pipefail

pushd buildpack > /dev/null
  if [ ! -f ./go.mod ]; then
      export GOPATH=$PWD
  fi
  export GOBIN=$PWD/.bin
  export PATH=$GOBIN:$PATH
popd > /dev/null

if [[ -e "${PWD}/buildpack/scripts/.util/tools.sh" ]]; then
  # shellcheck disable=SC1091
  source "${PWD}/buildpack/scripts/.util/tools.sh"
  util::tools::cf::install --directory "${PWD}/buildpack/.bin"
fi

"./cf-space/login"

pushd buildpack > /dev/null
  ./scripts/brats.sh
popd > /dev/null
