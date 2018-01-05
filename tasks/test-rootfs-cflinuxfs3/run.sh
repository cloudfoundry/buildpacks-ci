#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

SUFFIX="${STACKS_SUFFIX-}"

buildpacks-ci/scripts/start-docker

pushd cflinuxfs3
  cp ../cflinuxfs3-artifacts/cflinuxfs3"$SUFFIX"-*.tar.gz cflinuxfs3.tar.gz

  bundle install --jobs="$(nproc)"

  bundle exec rspec
popd
