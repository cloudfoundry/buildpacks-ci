#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

wget --quiet https://github.com/cloudfoundry/bosh-bootloader/releases/download/v5.11.5/bbl-v5.11.5_linux_x86-64
chmod 755 bbl-v5.11.5_linux_x86-64

pushd "bbl-state/$ENV_NAME"
  eval "$(../../bbl-v5.11.5_linux_x86-64 print-env)"
popd

bosh2 -d rootfs-smoke-test run-errand cflinuxfs2-smoke-test
pkill -f ssh
