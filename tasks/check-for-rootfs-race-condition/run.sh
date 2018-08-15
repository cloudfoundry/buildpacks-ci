#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail
set -x

version="$(cat version/version)"
latest_version="$(cat latest_version/version)"

if [[ "$version" != "$latest_version" ]]; then
  echo "There is another version of the rootfs in the pipeline"
  exit 1
fi
