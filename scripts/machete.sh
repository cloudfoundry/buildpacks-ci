#!/bin/bash -l

set -e

DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-`cat cf-environments/name`}
DOMAIN_NAME=${DOMAIN_NAME:-cf-app.com}

pushd buildpacks-ci
  ./scripts/start-docker
popd

pushd machete
  ./scripts/cf_login_and_setup $DOMAIN_NAME
  bundle
  bundle exec rspec
popd
