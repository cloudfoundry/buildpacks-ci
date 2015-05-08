#!/bin/bash -l
set -e

cd buildpack-packager
bundle
bundle exec rspec spec/
