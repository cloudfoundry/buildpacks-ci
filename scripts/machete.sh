#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

DEPLOYMENT_NAME=$(cat cf-environments/name)

pushd buildpacks-ci
  ./scripts/start-docker
popd

host="$DEPLOYMENT_NAME.$BOSH_LITE_DOMAIN_NAME"
pushd machete
  ./scripts/cf_login_and_setup "$host"
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  bundle
  bundle exec rspec
popd
