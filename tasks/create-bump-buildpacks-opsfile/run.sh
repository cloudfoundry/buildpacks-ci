#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

cd buildpacks-ci/
bundle install
gem install open4
tasks/create-bump-buildpacks-opsfile/run.rb
