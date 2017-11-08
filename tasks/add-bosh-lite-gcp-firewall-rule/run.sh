#!/usr/bin/env bash

echo "$GCP_SERVICE_ACCOUNT_KEY" > /tmp/gcp_key

set -o errexit
set -o nounset
set -o pipefail

gcloud auth activate-service-account --key-file /tmp/gcp_key

gcloud config set project cf-buildpacks

gcloud compute firewall-rules create "${ENV_NAME}"-bosh-lite-cf-ports \
  --allow=tcp:2222,tcp:443,tcp:80 \
  --description="Allow HTTP(s) and CF SSH access to bosh-lite for ${ENV_NAME} environment" \
  --network https://www.googleapis.com/compute/v1/projects/cf-buildpacks/global/networks/"${ENV_NAME}"-network

