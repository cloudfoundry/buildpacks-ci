#!/usr/bin/env bash
set -ex

pushd gem
  bump patch
  bump current | egrep -o '[0-9\.]+' >> VERSION
popd

rsync -a gem/ gem-artifacts
