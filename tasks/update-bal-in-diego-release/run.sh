#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd bal-develop
  BAL_DEV_SHA=$(git rev-parse HEAD)
popd

rsync -a diego-release updated-diego-release

pushd updated-diego-release/src/code.cloudfoundry.org/buildpacklifecycle
  git checkout "$BAL_DEV_SHA"
  git add .
popd

git commit -m 'Update buildpacklifecycle'
