#!/bin/bash -l
echo "Uploading bosh release..."
set -ex -o pipefail


echo "Targeting bosh director..."
pushd env-repo/$BOSH_ENV
  eval "$(bbl print-env)"
popd

echo "Uploading any matching releases..."
pushd bosh-release
  bosh upload-release $RELEASES_GLOB
popd

echo "All done."
