#!/usr/bin/env bash

set -ex
cd "$( dirname "${BASH_SOURCE[0]}" )/.."

bundle exec rspec --tag ~fly
pushd dockerfiles/depwatcher
  shards
  crystal spec --no-debug
popd

./tasks/run-buildpacks-ci-specs/fly-login.sh "$CI_USERNAME" "$CI_PASSWORD"
bundle exec rake

go test -v ./...

# Clean up directories
rm -rf source-*-latest
