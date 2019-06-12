#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

CF_API_URL=api."$APPS_DOMAIN"

sleep $((2 * 60))
CF_ADMIN_PASSWORD="$(tr -d '[:space:]' < cf-admin-password/password)"

cf api --skip-ssl-validation "$CF_API_URL"
cf auth "admin" "${CF_ADMIN_PASSWORD}"

cf set-running-environment-variable-group '{"CREDHUB_API": "https://credhub.service.cf.internal:8844/"}'

pushd "bbl-state/$ENV_NAME"
  set +o xtrace
  eval "$(bbl print-env)"
  set -o xtrace
  trap "pkill -f ssh" EXIT
  bosh2 instances -d cf --json | jq '.Tables[0].Rows | map(select(.instance | startswith("credhub\/") )) | map({"protocol":"tcp", "ports":"8844", "description": "Allow credhub traffic", "destination": .ips})' > credhub_security_group.json
  bosh2 instances -d cf --json | jq '.Tables[0].Rows | map(select(.instance | startswith("uaa\/") )) | map({"protocol":"tcp", "ports":"8443", "description": "Allow UAA traffic", "destination": .ips})' > uaa_security_group.json
popd

# CATs Credhub tests need to talk to credhub to create and interpolate credentials
cf create-security-group credhub "bbl-state/$ENV_NAME/credhub_security_group.json"
cf bind-running-security-group credhub
cf bind-staging-security-group credhub

# CATs Credhub tests deploy a service broker app which needs to talk to UAA
cf create-security-group uaa "bbl-state/$ENV_NAME/uaa_security_group.json"
cf bind-running-security-group uaa
cf bind-staging-security-group uaa
