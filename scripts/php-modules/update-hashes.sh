#!/usr/bin/env bash

# This script will systematically recompute hashes for specified php modules.
#
# To use this script, simply run it from the top-level of this repo after updating
# 'tasks/build-binary-new/php7-base-extensions.yml' and
# 'tasks/build-binary-new/php7-base-extensions.yml' as follows:
#
# 1. Update the 'version' field for each module being bumped
# 2. Clear the 'md5' field to signal that it should be recomputed
#
# NOTE: This script assumes that you have cloned
# https://github.com/cloudfoundry/binary-builder into a 'binary-builder'
# directory next to this repo. It also assumes you have bundler installed.

set -euo pipefail

cd "$(dirname "$0")"

bundle install
bundle exec run.rb
