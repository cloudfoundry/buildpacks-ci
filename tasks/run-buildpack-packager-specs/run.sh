#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

cd buildpack-packager

if [ ! -z "$RUBYGEM_MIRROR" ]; then
  bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
fi

bundle
bundle exec rspec spec/
