#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd buildpacks-ci
  # shellcheck disable=SC1091
  source ./bin/target_bosh "$DEPLOYMENT_NAME"
popd

export BOSH_RELEASES_DIR
BOSH_RELEASES_DIR=$(pwd)
export CF_RELEASE_DIR
CF_RELEASE_DIR="$(pwd)/cf-release"

pushd cf-release
  mkdir -p bosh-lite
  echo "
---
name: cf-warden
properties:
  domain: $DEPLOYMENT_NAME.$BOSH_LITE_DOMAIN_NAME
  system_domain: $DEPLOYMENT_NAME.$BOSH_LITE_DOMAIN_NAME
  acceptance_tests:
    admin_password: stub_to_be_gsubbed
    include_internet_dependent: true
    include_logging: true
    include_operator: false
    include_routing: false
    include_security_groups: true
    include_services: true
    include_sso: false
    include_v3: false
    include_diego_ssh: true
    include_diego_docker: true
    nodes: 4
    backend: diego
  cc:
    default_to_diego_backend: true

jobs:
- name: api_z1
  # Make the disk size bigger so we can handle
  # both offline and online buildpacks now.
  persistent_disk: 30720" >> bosh-lite/cf-stub-spiff-ours.yml

  ./scripts/generate-bosh-lite-dev-manifest bosh-lite/cf-stub-spiff-ours.yml

  ../buildpacks-ci/tasks/generate-cf-and-diego-manifests/swap-cf-release-scim-admin-password.rb "$(pwd)" bosh-lite/deployments/cf.yml
  ../buildpacks-ci/tasks/generate-cf-and-diego-manifests/swap-jwt-keys.rb "$(pwd)" bosh-lite/deployments/cf.yml

  ruby -i -pe "gsub('admin_password: stub_to_be_gsubbed', 'admin_password: ' + ENV.fetch('CI_CF_PASSWORD'))" bosh-lite/deployments/cf.yml
popd

pushd diego-release
  ./scripts/generate-diego-certs
  echo "
---
property_overrides:
  bbs:
    ca_cert: |
      $(<./diego-certs/diego-ca.crt)
    client_cert: |
      $(<./diego-certs/bbs-certs/client.crt)
    client_key: |
      $(<./diego-certs/bbs-certs/client.key)
    server_cert: |
      $(<./diego-certs/bbs-certs/server.crt)
    server_key: |
      $(<./diego-certs/bbs-certs/server.key)
  etcd:
    ca_cert: |
      $(<./diego-certs/diego-ca.crt)
    client_cert: |
      $(<./diego-certs/etcd-certs/client.crt)
    client_key: |
      $(<./diego-certs/etcd-certs/client.key)
    peer_ca_cert: |
      $(<./diego-certs/etcd-peer-ca.crt)
    peer_cert: |
      $(<./diego-certs/etcd-certs/peer.crt)
    peer_key: |
      $(<./diego-certs/etcd-certs/peer.key)
    server_cert: |
      $(<./diego-certs/etcd-certs/server.crt)
    server_key: |
      $(<./diego-certs/etcd-certs/server.key)" > bosh-lite/update-certs-spiff.yml
  spiff merge manifest-generation/bosh-lite-stubs/property-overrides.yml bosh-lite/update-certs-spiff.yml
  USE_SQL='postgres' ./scripts/generate-bosh-lite-manifests
  ../buildpacks-ci/tasks/generate-cf-and-diego-manifests/swap-diego-rootfs-release.rb "$(pwd)" bosh-lite/deployments/diego.yml

  if [ "$IAAS" = "gcp"  ]; then
    echo "Setting garden network mtu to 1432"
    ruby -i -pe "gsub('network_mtu: null', 'network_mtu: 1432')" bosh-lite/deployments/diego.yml
  fi

  ruby -i -pe "gsub('diego_privileged_containers: null', 'diego_privileged_containers: true')" bosh-lite/deployments/diego.yml
popd

MANIFEST_DIR="generate-manifest-artifacts/$DEPLOYMENT_NAME"
mkdir -p "$MANIFEST_DIR"

cp cf-release/bosh-lite/deployments/cf.yml "$MANIFEST_DIR/manifest.yml"
cp diego-release/bosh-lite/deployments/diego.yml "$MANIFEST_DIR/diego.yml"
