#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

DEPLOYMENT_NAME=$(cat cf-environments/name)

pushd brats
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  bundle install
  if [ -n "$CI_CF_PASSWORD" ]; then
    cf login -a "api.$DEPLOYMENT_NAME.$BOSH_LITE_DOMAIN_NAME" -u "$CI_CF_USERNAME" -p "$CI_CF_PASSWORD" -o pivotal -s integration --skip-ssl-validation
  fi

  if [ -z "${STACK-}" ]; then
    bundle exec rspec cf_spec/integration --tag language:"${LANGUAGE}"
  else
    bundle exec rspec -t "stack:$STACK" cf_spec/integration --tag language:"${LANGUAGE}"
  fi
popd
