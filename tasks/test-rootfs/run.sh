#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

SUFFIX="${STACKS_SUFFIX-}"

buildpacks-ci/scripts/start-docker

pushd stacks
  cp ../stacks-artifacts/cflinuxfs2"$SUFFIX"-*.tar.gz cflinuxfs2.tar.gz

  bundle install --jobs="$(nproc)"

  bundle exec rspec
popd
