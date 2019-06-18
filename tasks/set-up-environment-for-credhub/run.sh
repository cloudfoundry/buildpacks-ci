#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

CF_API_URL=api."$APPS_DOMAIN"
SECURITY_GROUP_NAME=credhub

sleep $((2 * 60))
CF_ADMIN_PASSWORD="$(tr -d '[:space:]' < cf-admin-password/password)"

cf api --skip-ssl-validation "$CF_API_URL"
cf auth "admin" "${CF_ADMIN_PASSWORD}"

pushd "bbl-state/$ENV_NAME"
  set +o xtrace
  eval "$(bbl print-env)"
  set -o xtrace

  credhubIPs=$(bosh -d cf instances | grep credhub | awk '{print $4}')
  asgJson=$(mktemp)
  echo "$credhubIPs" | jq -R '{"protocol": "tcp", "destination": ., "ports": "8844"}' | jq -s . > "$asgJson"
popd

cf delete-security-group -f "$SECURITY_GROUP_NAME"
cf create-security-group "$SECURITY_GROUP_NAME" "$asgJson"

cf bind-running-security-group "$SECURITY_GROUP_NAME"
cf bind-staging-security-group "$SECURITY_GROUP_NAME"