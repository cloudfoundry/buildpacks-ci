#!/bin/bash -l

set -euo pipefail

version=$(cat version/version)

pushd shim
    ./scripts/build.sh
popd

tar czf archive/shim-bundle.tgz detect supply finalize release

sha=$(sha256sum archive/shim-bundle.tgz | cut -d ' ' -f 1)

mv archive/shim-bundle.tgz "archive/shim-bundle-$version-${sha::8}.tgz"
