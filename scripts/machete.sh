#!/bin/bash -l

set -e

cd machete
bundle
bundle exec rspec
