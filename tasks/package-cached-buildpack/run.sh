#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

pushd buildpack-master
  export BUNDLE_GEMFILE=cf.Gemfile
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  bundle install
  bundle exec buildpack-packager --cached

  VERSION=$(cat VERSION)
popd

TIMESTAMP=$(date +%s)

CACHED_BUILDPACK="buildpack-master/dotnet-core_buildpack-cached-v$VERSION.zip"
CACHED_TIMESTAMP_BUILDPACK="buildpack-artifacts/dotnet-core_buildpack-cached-v$VERSION+$TIMESTAMP.zip"

mv "$CACHED_BUILDPACK" "$CACHED_TIMESTAMP_BUILDPACK"

echo md5: "$(md5sum "$CACHED_TIMESTAMP_BUILDPACK")"
echo sha256: "$(sha256sum "$CACHED_TIMESTAMP_BUILDPACK")"
