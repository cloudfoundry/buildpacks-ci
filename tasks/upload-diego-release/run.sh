#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

bosh2 -n upload-release diego-bosh-release/release.tgz
