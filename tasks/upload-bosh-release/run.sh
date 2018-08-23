#!/bin/bash -l
set -ex -o pipefail

# Target the bosh director
pushd env-repo/$BOSH_ENV
  eval "$(bbl print-env)"
popd

# Upload any matching releases
pushd bosh-release
  bosh upload-release $RELEASES_GLOB
popd
