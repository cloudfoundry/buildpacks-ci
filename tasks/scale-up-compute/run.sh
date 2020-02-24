#!/bin/bash

set -eu
set -o pipefail

readonly ENVIRONMENT_DIR="${PWD}/environment"

function main() {
  local target username password
  target="$(jq -r .ops_manager.url "${ENVIRONMENT_DIR}/metadata")"
  username="$(jq -r .ops_manager.username "${ENVIRONMENT_DIR}/metadata")"
  password="$(jq -r .ops_manager.password "${ENVIRONMENT_DIR}/metadata")"

  cat <<-YAML > /tmp/product.yml
---
product-name: cf
resource-config:
  compute:
    instances: ${INSTANCE_COUNT}
YAML

  om -k \
    --target "${target}" \
    --username "${username}" \
    --password "${password}" \
      configure-product \
      --config /tmp/product.yml

  om -k \
    --target "${target}" \
    --username "${username}" \
    --password "${password}" \
      apply-changes \
      --product-name cf
}

main
