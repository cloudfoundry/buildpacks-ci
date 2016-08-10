#!/bin/bash -l

set -e

DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-`cat cf-environments/name`}
DOMAIN_NAME=${DOMAIN_NAME:-cf-app.com}

pushd buildpacks-ci
  ./scripts/start-docker
popd

host="$DEPLOYMENT_NAME.$DOMAIN_NAME"
pushd machete
  ./scripts/cf_login_and_setup $host
  bundle config mirror.https://rubygems.org ${RUBYGEM_MIRROR}
  bundle
  bundle exec rspec
popd
