#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd bal-develop
  BAL_DEV_SHA=$(git rev-parse HEAD)
popd

rsync -a diego-release/ updated-diego-release

pushd updated-diego-release
  pushd src/code.cloudfoundry.org/buildpackapplifecycle
    git checkout "$BAL_DEV_SHA"
  popd

  if [ -n "$(git status --porcelain)" ] ; then
    git add .
    git config --global alias.ci commit
    ./scripts/commit-with-submodule-log src/code.cloudfoundry.org/buildpackapplifecycle
  fi
popd
