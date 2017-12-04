#!/usr/bin/env bash

echo "$GCP_SERVICE_ACCOUNT_KEY" > /tmp/gcp_key

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

ENV_NAME=${ENV_NAME:-}
ZONE_NAME="${ENV_NAME}"-zone
DNS_NAME="${ENV_NAME}.buildpacks-gcp.ci.cf-app.com."

gcloud auth activate-service-account --key-file /tmp/gcp_key

gcloud config set project cf-buildpacks


if [ "${DNS_NAME}" != "$(gcloud dns record-sets list --zone=buildpacks --type=NS --name="${DNS_NAME}" --format="value(name)")" ] ; then
  NAMESERVERS=$(gcloud dns managed-zones describe "${ZONE_NAME}" --format='value[delimiter="
"](nameServers)')

  gcloud dns record-sets transaction start --zone=buildpacks

    # shellcheck disable=SC2086
    gcloud dns record-sets transaction add ${NAMESERVERS} --name "${DNS_NAME}" --ttl=300 --type=NS --zone=buildpacks

  gcloud dns record-sets transaction execute --zone=buildpacks
fi

