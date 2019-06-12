#!/usr/bin/env bash
set -eux
set -o pipefail

set +x
pushd "bbl-state/${BBL_STATE_DIR}"
  eval "$(bbl print-env)"
popd
set -x

bosh -n update-runtime-config bosh-deployment/runtime-configs/dns.yml --name dns
