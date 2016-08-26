#!/bin/bash -l

set -ex

pushd binary-builder
  gem install bundler --no-ri --no-rdoc
  bundle config mirror.https://rubygems.org ${RUBYGEM_MIRROR}
  bundle install -j4

  bundle exec rspec spec/unit
popd
