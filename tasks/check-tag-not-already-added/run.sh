#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd buildpack
TEST_VERSION=${VERSION:-$(cat VERSION)}
git tag "v${TEST_VERSION}"
