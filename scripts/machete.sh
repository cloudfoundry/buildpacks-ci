#!/bin/bash -l

set -e

pushd machete
  bundle
  bundle exec rspec
popd
