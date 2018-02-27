#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

CF_API_URL=api."$APPS_DOMAIN"

cf api --skip-ssl-validation "$CF_API_URL"
cf auth "$CI_CF_USERNAME" "$CI_CF_PASSWORD"

cf set-running-environment-variable-group '{"CREDHUB_API": "https://credhub.service.cf.internal:8844/"}'

wget --quiet https://github.com/cloudfoundry/bosh-bootloader/releases/download/v5.11.5/bbl-v5.11.5_linux_x86-64
chmod 755 bbl-v5.11.5_linux_x86-64

pushd "bbl-state/$ENV_NAME"
  eval "$(../../bbl-v5.11.5_linux_x86-64 print-env)"
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

pkill -f ssh
