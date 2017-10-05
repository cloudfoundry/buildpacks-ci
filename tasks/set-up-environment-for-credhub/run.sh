#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

CF_API_URL=api."$APPS_DOMAIN"

cf api --skip-ssl-validation "$CF_API_URL"
cf auth "$CI_CF_USERNAME" "$CI_CF_PASSWORD"

cf set-running-environment-variable-group '{"CREDHUB_API": "https://credhub.service.cf.internal:8844/"}'

cd bbl-state
eval "$(bbl print-env)"

bosh2 instances -d cf --json | jq '.Tables[0].Rows | map(select(.instance | startswith("credhub\/") )) | map({"protocol":"tcp", "ports":"8844", "description": "Allow credhub traffic", "destination": .ips})' > security_group.json

cf create-security-group credhub security_group.json
cf bind-running-security-group credhub
cf bind-staging-security-group credhub

