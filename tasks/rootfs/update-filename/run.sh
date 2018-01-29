#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

source="stack-s3/${ROOTFS}-*.tar.gz"
destination=rootfs-archive/${ROOTFS}-$(cat version/number).tar.gz

# here, we actually want globbing, so:
# shellcheck disable=SC2086
mv $source "$destination"
