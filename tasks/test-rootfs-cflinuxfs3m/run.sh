#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

SUFFIX="${STACKS_SUFFIX-}"

buildpacks-ci/scripts/start-docker

pushd cflinuxfs3m
  cp ../cflinuxfs3m-artifacts/cflinuxfs3m"$SUFFIX"-*.tar.gz cflinuxfs3m.tar.gz

  bundle install --jobs="$(nproc)"

  bundle exec rspec
popd
