#!/usr/bin/env bash

echo "$GCP_SERVICE_ACCOUNT_KEY" > /tmp/gcp_key

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

ENV_NAME=${ENV_NAME:-}
ZONE_NAME="${ENV_NAME}"-zone
DNS_NAME="${ENV_NAME}.buildpacks-gcp.ci.cf-app.com."
BOSH_LITE_IP=$(cd bbl-state/"${ENV_NAME}" && bbl bosh-deployment-vars | grep external_ip | awk '{print $2}')

gcloud auth activate-service-account --key-file /tmp/gcp_key

gcloud config set project cf-buildpacks

#1. create zone, or remove any records from existing zone
if [ "${ZONE_NAME}" = "$(gcloud dns managed-zones list --filter="name=(cflinuxfs2-zone)" --format=json | jq -r '.[0]["name"]')" ]; then
  gcloud dns record-sets transaction start --zone="${ZONE_NAME}"
  for DNS_RECORD_SET in $(gcloud dns record-sets list --zone cflinuxfs2-zone --filter="type=(A)" --format="csv[no-heading](name,ttl,rrdatas)"); do
    NAME=$(awk -F, '{ print $1 }' <<<"$DNS_RECORD_SET")
    TTL=$(awk -F, '{ print $2 }' <<<"$DNS_RECORD_SET")
    IP_ADDR=$(awk -F, '{ print $3 }' <<<"$DNS_RECORD_SET")
    gcloud dns record-sets transaction remove "${IP_ADDR}" --name="${NAME}" --ttl="${TTL}" --type=A --zone="${ZONE_NAME}"
  done
  gcloud dns record-sets transaction execute --zone="${ZONE_NAME}"
else
  gcloud dns managed-zones create "${ZONE_NAME}" --description="${ENV_NAME} Zone" --dns-name="${DNS_NAME}"
fi


#2. add records for newly BBL'd BOSH director
gcloud dns record-sets transaction start --zone="${ZONE_NAME}"

  for DNS_NAME_PREFIX in '*' '*.ws' bosh doppler loggregator ssh tcp; do
    gcloud dns record-sets transaction add "${BOSH_LITE_IP}" --name="${DNS_NAME_PREFIX}.${DNS_NAME}" --ttl=300 --type=A --zone="${ZONE_NAME}"
  done

gcloud dns record-sets transaction execute --zone="${ZONE_NAME}"


#3. add the parent zone (buildpacks zone) subdomain NS records if they don't already exist
if [ "${DNS_NAME}" != "$(gcloud dns record-sets list --zone=buildpacks --type=NS --name="${DNS_NAME}" --format="value(name)")" ] ; then
  NAMESERVERS=$(gcloud dns managed-zones describe "${ZONE_NAME}" --format='value[delimiter="
"](nameServers)')

  gcloud dns record-sets transaction start --zone=buildpacks

    # shellcheck disable=SC2086
    gcloud dns record-sets transaction add ${NAMESERVERS} --name "${DNS_NAME}" --ttl=300 --type=NS --zone=buildpacks

  gcloud dns record-sets transaction execute --zone=buildpacks
fi

