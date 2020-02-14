#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

#shellcheck source=../../scripts/start-docker
source ./buildpacks-ci/scripts/start-docker
util::docker::start
trap util::docker::start EXIT

pushd cflinuxfs2
  cp ../cflinuxfs2-artifacts/"$STACK"-*.tar.gz "$STACK.tar.gz"

  bundle install --jobs="$(nproc)" --deployment
  bundle cache

  bundle exec rspec
popd
