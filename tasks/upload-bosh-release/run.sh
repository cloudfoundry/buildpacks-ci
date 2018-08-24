#!/bin/bash -l
set -xeuo pipefail

echo "Targeting bosh director..."
pushd "env-repo/$BOSH_ENV"
  set +x
  eval "$(bbl print-env)"
  set -x
  trap "pkill -f ssh" EXIT
popd

echo "Uploading any matching releases..."
pushd bosh-release
  # shellcheck disable=SC2086
  bosh upload-release $RELEASE
popd

echo "All done."
