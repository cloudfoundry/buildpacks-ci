#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd gem
  bump patch
  bump current | grep -E -o '[0-9\.]+' >> VERSION
popd

rsync -a gem/ gem-artifacts
