#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd buildpacks-ci
  ./scripts/start-docker
popd

./cf-space/login

pushd machete
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  bundle
  bundle exec rspec
popd
