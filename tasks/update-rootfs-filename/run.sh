#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

SUFFIX="${ROOTFS_SUFFIX-}"

source="stack-s3/${STACK}${SUFFIX}-*.tar.gz"
destination="rootfs-archive/${STACK}${SUFFIX}-$(cat version/number).tar.gz"

# here, we actually want globbing, so:
# shellcheck disable=SC2086
mv $source "$destination"
