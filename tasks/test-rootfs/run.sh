#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

buildpacks-ci/scripts/start-docker

pushd rootfs
  cp "../rootfs-artifacts/$STACK-*.tar.gz" "$STACK.tar.gz"

  bundle install --jobs="$(nproc)"

  bundle exec rspec
popd
