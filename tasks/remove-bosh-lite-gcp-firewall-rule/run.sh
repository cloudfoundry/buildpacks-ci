#!/usr/bin/env bash

echo "$GCP_SERVICE_ACCOUNT_KEY" > /tmp/gcp_key

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

gcloud auth activate-service-account --key-file /tmp/gcp_key

gcloud config set project cf-buildpacks

gcloud compute firewall-rules delete "${ENV_NAME}"-bosh-lite-cf-ports --quiet || echo Couldnt remove firewall rule

