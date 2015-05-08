#!/bin/bash -l

set -e

pushd compile-extensions
  bundle
  bundle exec rspec
popd
