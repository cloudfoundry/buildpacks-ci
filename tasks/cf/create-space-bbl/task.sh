#!/bin/bash

set -eux
set -o pipefail

readonly BBL_STATE="${PWD}/bbl-state/${BBL_STATE_DIR}"
readonly SPACE_DIR="${PWD}/space"

#shellcheck source=../../../util/print.sh
source "${PWD}/ci/util/print.sh"

function main() {
  util::print::title "[task] executing"

  echo "=== DEBUG: Environment variables ==="
  echo "BBL_STATE_DIR: ${BBL_STATE_DIR}"
  echo "SYSTEM_DOMAIN: ${SYSTEM_DOMAIN}"
  echo "ORG: ${ORG}"
  echo "PWD: ${PWD}"
  echo "BBL_STATE path: ${BBL_STATE}"
  
  echo "=== DEBUG: Directory structure ==="
  ls -la "${PWD}"
  echo "=== DEBUG: bbl-state contents ==="
  ls -la "${PWD}/bbl-state/" || echo "bbl-state directory not found"
  echo "=== DEBUG: BBL_STATE_DIR contents ==="
  ls -la "${BBL_STATE}" || echo "BBL_STATE directory not found"

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

  echo "=== DEBUG: Entering BBL_STATE directory: ${BBL_STATE} ==="
  pushd "${BBL_STATE}" > /dev/null
    echo "=== DEBUG: Running 'bbl print-env' ==="
    bbl print-env
    echo "=== DEBUG: Evaluating bbl print-env ==="
    eval "$(bbl print-env)"
  popd > /dev/null

  echo "=== DEBUG: Fetching CF admin password from credhub ==="
  local credhub_path="/bosh-${SYSTEM_DOMAIN//./-}/cf/cf_admin_password"
  echo "Credhub path: ${credhub_path}"
  
  local password
  password="$(credhub get --name "${credhub_path}" --output-json | jq -r .value)"
  echo "Password fetched (length: ${#password})"

  local api_url="https://api.${SYSTEM_DOMAIN}"
  echo "=== DEBUG: CF API URL: ${api_url} ==="

  cf api "$api_url" --skip-ssl-validation

  echo "cf api \"${api_url}\" --skip-ssl-validation" >> "${SPACE_DIR}/login"

  echo "=== DEBUG: Authenticating as admin ==="
  cf auth admin "${password}"

  echo "echo \"Logging in to ${api_url}\"" >> "${SPACE_DIR}/login"
  echo "cf auth admin \"${password}\"" >> "${SPACE_DIR}/login"
}

function cf::space::create() {
  util::print::info "[task] * creating CF space"

  local space
  space="$(openssl rand -base64 32 | base64 | head -c 8 | awk '{print tolower($0)}')"
  echo "=== DEBUG: Generated space name: ${space} ==="

  echo "=== DEBUG: Creating org ${ORG} ==="
  cf create-org "${ORG}" || true
  
  echo "=== DEBUG: Creating space ${space} in org ${ORG} ==="
  cf create-space "${space}" -o "${ORG}"

  echo "echo \"Targetting ${ORG} org and ${space} space\"" >> "${SPACE_DIR}/login"
  echo "cf target -o \"${ORG}\" -s \"${space}\"" >> "${SPACE_DIR}/login"

  echo "${space}" > "${SPACE_DIR}/name"
  echo "export SPACE=${space}" > "${SPACE_DIR}/variables"
  
  echo "=== DEBUG: Space created successfully ==="
  echo "Space name written to: ${SPACE_DIR}/name"
  echo "Space variables written to: ${SPACE_DIR}/variables"
}

main "${@}"
