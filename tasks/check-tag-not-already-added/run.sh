#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

VERSION=""
if [[ -d "version" ]]; then
    VERSION=$(cat version/version)
else
    VERSION=$(cat buildpack/VERSION)
fi

cd buildpack
git tag "v${VERSION}"
