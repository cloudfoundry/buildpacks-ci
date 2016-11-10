#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd binary-builder
  if [ -n "${RUBYGEM_MIRROR}" ]; then
    gem sources --clear-all --add "$RUBYGEM_MIRROR"
  fi
  gem install bundler --no-ri --no-rdoc
  bundle config mirror.https://rubygems.org "$RUBYGEM_MIRROR"
  bundle install --jobs="$(nproc)"

  bundle exec rspec spec/unit
popd
