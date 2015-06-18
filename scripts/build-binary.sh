#!/bin/bash -l
set -e

cd binary-builder
./bin/binary-builder $BINARY_NAME $BINARY_VERSION

if [[ $BINARY_NAME == 'jruby' && $BINARY_VERSION == *"9.0.0.0"* ]]; then
  binary_tarball="${BINARY_NAME}-${BINARY_VERSION}-linux-x64.tgz"
  semver_version="0.0.0-${BINARY_VERSION:8:(${#BINARY_VERSION}-8)}"
  semver_tarball="jruby9000-${semver_version}-linux-x64.tgz"

  mv $binary_tarball $semver_tarball
fi
