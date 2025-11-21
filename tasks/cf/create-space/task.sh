#!/bin/bash

set -eu
set -o pipefail

readonly BBL_STATE="${PWD}/bbl-state/${BBL_STATE_DIR}"
readonly SPACE_DIR="${PWD}/space"

#shellcheck source=../../../util/print.sh
source "${PWD}/ci/util/print.sh"

function main() {
  util::print::title "[task] executing"
  util::print::info "BBL_STATE_DIR: ${BBL_STATE_DIR}"
  util::print::info "SYSTEM_DOMAIN: ${SYSTEM_DOMAIN}"
  util::print::info "ORG: ${ORG}"
  util::print::info "PWD: ${PWD}"
  util::print::info "BBL_STATE path: ${BBL_STATE}"

  space::setup
  cf::authenticate
  cf::space::create
}

function space::setup() {
  util::print::info "[task] * creating space login script"

  cat <<LOGIN > "${SPACE_DIR}/login"
#!/bin/bash
set +x
LOGIN
  chmod 755 "${SPACE_DIR}/login"
}

function cf::authenticate() {
  util::print::info "[task] * authenticating with CF environment"

  pushd "${BBL_STATE}" > /dev/null    
    eval "$(bbl print-env)"
    # Get the BBL environment name from bbl-state.json
    local bbl_env_name=$(jq -r '.envID' bbl-state.json)
  popd > /dev/null

  # Fetching CF admin password from credhub"
  # Credhub path similar to '/bosh-r-buildpack-bbl-env/cf/cf_admin_password'
  local credhub_path="/bosh-${bbl_env_name}/cf/cf_admin_password"
  
  local password="$(credhub get --name "${credhub_path}" --output-json | jq -r .value)"

  api_url="https://api.${SYSTEM_DOMAIN}"

  cf api "$api_url" --skip-ssl-validation

  echo "cf api \"${api_url}\" --skip-ssl-validation" >> "${SPACE_DIR}/login"

  cf auth admin "${password}"

  echo "echo \"Logging in to ${api_url}\"" >> "${SPACE_DIR}/login"
  echo "cf auth admin \"${password}\"" >> "${SPACE_DIR}/login"
}

function cf::space::create() {
  util::print::info "[task] * creating CF space"

  local space
  space="$(openssl rand -base64 32 | base64 | head -c 8 | awk '{print tolower($0)}')"

  cf create-org "${ORG}"
  cf create-space "${space}" -o "${ORG}"

  echo "echo \"Targetting ${ORG} org and ${space} space\"" >> "${SPACE_DIR}/login"
  echo "cf target -o \"${ORG}\" -s \"${space}\"" >> "${SPACE_DIR}/login"

  echo "${space}" > "${SPACE_DIR}/name"
  echo "export SPACE=${space}" > "${SPACE_DIR}/variables"
}

main "${@}"
