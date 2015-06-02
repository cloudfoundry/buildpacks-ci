#!/bin/bash -l

set -e

cd binary-builder
gem install bundler --no-ri --no-rdoc
bundle install -j4
bundle exec rspec
