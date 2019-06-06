#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

pushd "bbl-state/$ENV_NAME"
  set +x
  eval "$(bbl print-env)"
  set -x
popd
  credhub get -n /bosh-"$ENV_NAME"/cf/cf_admin_password -j | jq -r .value > cf-admin-password/password

