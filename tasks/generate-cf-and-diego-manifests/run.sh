#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd deployments-buildpacks
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  bundle install --jobs="$(nproc)"
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

  ruby -i -pe "gsub('admin_password: stub_to_be_gsubbed', 'admin_password: ' + ENV['CI_CF_PASSWORD'])" bosh-lite/deployments/cf.yml
popd

pushd diego-release
  USE_SQL='postgres' ./scripts/generate-bosh-lite-manifests
  ../buildpacks-ci/tasks/generate-cf-and-diego-manifests/swap-diego-rootfs-release.rb "$(pwd)" bosh-lite/deployments/diego.yml
  ruby -i -pe "gsub('network_mtu: null', 'network_mtu: 1432')" bosh-lite/deployments/diego.yml
popd

pushd deployments-buildpacks
  cp ../cf-release/bosh-lite/deployments/cf.yml "deployments/$DEPLOYMENT_NAME/manifest.yml"
  cp ../diego-release/bosh-lite/deployments/diego.yml "deployments/$DEPLOYMENT_NAME/diego.yml"

  git add "deployments/$DEPLOYMENT_NAME/*.yml"
  git diff-index --quiet HEAD "deployments/$DEPLOYMENT_NAME/manifest.yml" || git commit -qm "Update manifests for $DEPLOYMENT_NAME"
popd

rsync -a deployments-buildpacks/ generate-manifest-artifacts
