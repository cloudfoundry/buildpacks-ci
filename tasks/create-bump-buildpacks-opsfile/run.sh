#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

cd buildpacks-ci/
bundle install
cd ..
gem install open4
buildpacks-ci/tasks/create-bump-buildpacks-opsfile/run.rb
