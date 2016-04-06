#!/bin/bash -l

set -e

pushd buildpacks-ci
  ./scripts/start-docker
popd

pushd machete
  bundle
  bundle exec rspec
popd
