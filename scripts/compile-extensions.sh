#!/bin/bash

set -e

echo "Using ruby version $(ruby -v)"
cd compile-extensions
bundle config mirror.https://rubygems.org "$RUBYGEM_MIRROR"
bundle
bundle exec rspec
