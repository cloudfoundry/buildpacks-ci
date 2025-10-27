#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

VERSION=""
if [[ -d "version" ]]; then
    if [[ -f "version/number" ]]; then
        VERSION=$(cat version/number)
    elif [[ -f "version/version" ]]; then
        VERSION=$(cat version/version)
    fi
else
    VERSION=$(cat buildpack/VERSION)
fi

cd buildpack
git tag "v${VERSION}"
