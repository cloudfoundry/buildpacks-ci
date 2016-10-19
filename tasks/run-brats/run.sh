#!/bin/bash -l
set -e

DEPLOYMENT_NAME=$(cat cf-environments/name)
BOSH_LITE_DOMAIN_NAME=${BOSH_LITE_DOMAIN_NAME:-cf-app.com}

cd brats
bundle config mirror.https://rubygems.org "$RUBYGEM_MIRROR"
bundle install
if [ -n "$CI_CF_PASSWORD" ]; then
  cf login -a "api.$DEPLOYMENT_NAME.$BOSH_LITE_DOMAIN_NAME" -u "$CI_CF_USERNAME" -p "$CI_CF_PASSWORD" -o pivotal -s integration --skip-ssl-validation
fi

if [ "$STACK" == "" ]; then
  bundle exec rspec cf_spec/integration --tag language:"${LANGUAGE}"
else
  bundle exec rspec -t "stack:$STACK" cf_spec/integration --tag language:"${LANGUAGE}"
fi
