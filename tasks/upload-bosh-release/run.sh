#!/bin/bash -l
set -xeuo pipefail

echo "Targeting bosh director..."
pushd "bbl-state/$BBL_STATE_DIR"
  set +x
  eval "$(bbl print-env)"
  set -x
popd

echo "Uploading any matching releases..."
pushd bosh-release
  # shellcheck disable=SC2086
  bosh upload-release $RELEASE
popd

echo "All done."
