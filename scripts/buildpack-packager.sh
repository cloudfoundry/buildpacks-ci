#!/bin/bash -l
set -e

pushd buildpack-packager
  bundle
  bundle exec rspec spec/
popd
