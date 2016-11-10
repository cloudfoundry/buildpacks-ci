#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd buildpack
git tag "v$(cat VERSION)"
