#!/bin/bash -l

set -e

cd binary-builder
bundle install -j4
bundle exec rspec
