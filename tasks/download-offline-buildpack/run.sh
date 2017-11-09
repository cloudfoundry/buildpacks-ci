#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

ls -l pivnet-production

# shellcheck disable=SC2035
mv pivnet-production/java-buildpack-offline*.zip buildpack-zip/
