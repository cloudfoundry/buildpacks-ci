#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

set -x

cd buildpacks-site
yarn install --no-progress
yarn run unit
yarn run e2e
yarn run build
