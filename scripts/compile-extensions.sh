#!/bin/bash -l

set -e

cd compile-extensions
bundle
bundle exec rspec
