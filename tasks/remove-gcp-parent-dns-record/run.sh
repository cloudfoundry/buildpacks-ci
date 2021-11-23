#!/usr/bin/env bash

echo "$GCP_SERVICE_ACCOUNT_KEY" > /tmp/gcp_key

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

ENV_NAME=${ENV_NAME:-}
DNS_NAME="${ENV_NAME}.buildpacks-gcp.ci.cf-app.com."

gcloud auth activate-service-account --key-file /tmp/gcp_key

gcloud config set project cf-buildpacks

# get the NS
NAMESERVERS=$(gcloud dns record-sets list -z buildpacks | grep "$ENV_NAME" | awk '{ print $4 }'| tr , ' ')

if [ -z "$NAMESERVERS" ]; then
  echo "There are no record sets matching ${ENV_NAME}"
  echo "Skipping..."
  exit 0
fi

# remove the parent zone (buildpacks zone) subdomain NS records
gcloud dns record-sets transaction start --zone=buildpacks
  # shellcheck disable=SC2086
  gcloud dns record-sets transaction remove ${NAMESERVERS} --name "${DNS_NAME}" --ttl=300 --type=NS --zone=buildpacks
gcloud dns record-sets transaction execute --zone=buildpacks
