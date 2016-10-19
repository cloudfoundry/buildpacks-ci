#!/bin/bash -l
set -e

cd buildpack-packager
bundle config mirror.https://rubygems.org "$RUBYGEM_MIRROR"
bundle
bundle exec rspec spec/
