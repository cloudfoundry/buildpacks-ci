#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

cd buildpack-packager
bundle config mirror.https://rubygems.org "$RUBYGEM_MIRROR"
bundle
bundle exec rspec spec/
