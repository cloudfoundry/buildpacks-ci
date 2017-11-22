#!/usr/bin/env bash

echo "$GCP_SERVICE_ACCOUNT_KEY" > /tmp/gcp_key

RULE_NAME="${ENV_NAME}-bosh-lite-cf-ports"

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

gcloud auth activate-service-account --key-file /tmp/gcp_key

gcloud config set project cf-buildpacks

if [ "${RULE_NAME}" = "$(gcloud compute firewall-rules list --filter="name=(${RULE_NAME})" --format=json | jq -r '.[0]["name"]')" ]; then
  gcloud compute firewall-rules delete "${RULE_NAME}" --quiet
fi

gcloud compute firewall-rules create "${RULE_NAME}" \
  --allow=tcp:2222,tcp:443,tcp:80 \
  --description="Allow HTTP(s) and CF SSH access to bosh-lite for ${ENV_NAME} environment" \
  --network https://www.googleapis.com/compute/v1/projects/cf-buildpacks/global/networks/"${ENV_NAME}"-network

