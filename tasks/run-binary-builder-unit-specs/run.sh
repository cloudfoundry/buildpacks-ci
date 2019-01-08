#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd binary-builder
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    gem sources --clear-all --add "${RUBYGEM_MIRROR}"
  fi
  gem install bundler --no-document

  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi

  bundle install --jobs="$(nproc)"

  bundle exec rspec spec/unit
popd
