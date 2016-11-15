#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Using ruby version $(ruby -v)"
cd compile-extensions

if [ ! -z "$RUBYGEM_MIRROR" ]; then
  bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
fi

bundle
bundle exec rspec
