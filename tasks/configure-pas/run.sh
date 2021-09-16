#!/bin/bash

set -eu
set -o pipefail

readonly ENVIRONMENT_DIR="${PWD}/environment"

function main() {
  local target username password lbname
  target="$(jq -r .ops_manager.url "${ENVIRONMENT_DIR}/metadata")"
  username="$(jq -r .ops_manager.username "${ENVIRONMENT_DIR}/metadata")"
  password="$(jq -r .ops_manager.password "${ENVIRONMENT_DIR}/metadata")"
  lbname="$(jq -r .tcp_router_pool "${ENVIRONMENT_DIR}/metadata")"

  cat <<-YAML > /tmp/product.yml
---
product-name: cf
product-properties:
  .properties.tcp_routing:
    value: enable
  .properties.tcp_routing.enable.reservable_ports:
    value: 1024-1123
resource-config:
  compute:
    instances: ${COMPUTE_INSTANCE_COUNT}
  tcp_router:
    elb_names:
    - tcp:${lbname}
errand-config:
  smoke_tests:
    post-deploy-state: false
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
