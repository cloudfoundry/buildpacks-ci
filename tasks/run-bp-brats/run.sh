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

"./cf-space/login"

pushd buildpack > /dev/null
  ./scripts/brats.sh
popd > /dev/null
