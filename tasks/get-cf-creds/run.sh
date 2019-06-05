#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

pushd "bbl-state/$ENV_NAME"
set +x
eval "$(bbl print-env)"
set -x
trap "pkill -f ssh" EXIT
popd


#bbl_env, err = Open3.capture3("bbl --state-dir #{env_home} print-env")
#31     err_handle(err)
#➤  32     cf_pass, err, status = Open3.capture3("eval \"#{bbl_env}\" && credhub get -n /bosh-#{env_name}/cf/                       cf_admin_password -j | jq -r .value")
#33     err_handle(err)
