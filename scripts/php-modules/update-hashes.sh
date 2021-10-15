#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

bundle install
bundle exec ruby update-hashes.rb
