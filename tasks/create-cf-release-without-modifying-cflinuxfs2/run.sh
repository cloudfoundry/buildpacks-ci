#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd cf-release
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  bundle
  bosh create release --force --with-tarball --name cf --version "212.0.$(date +"%s")"
popd

rsync -a cf-release/ cf-release-artifacts
