#!/bin/bash -l

set -e

../buildpacks-ci/scripts/start-docker

pushd machete
  bundle
  bundle exec rspec
popd
