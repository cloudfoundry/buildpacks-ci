#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd brats
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  bundle install
  if [ -n "$CI_CF_PASSWORD" ]; then
    space="brats-$LANGUAGE"

    cf login -a "api.buildpacks-shared.cf-app.com" -u "$CI_CF_USERNAME" -p "$CI_CF_PASSWORD" -o pivotal -s "$space" --skip-ssl-validation || true

    cf create-org pivotal
    cf target -o pivotal

    cf create-space "$space" -o pivotal
    cf target -s "$space" -o pivotal
  fi

  if [ -z "${STACK-}" ]; then
    bundle exec rspec cf_spec/integration --tag language:"${LANGUAGE}" --tag buildpack_branch:"${BUILDPACK_BRANCH}"
  else
    bundle exec rspec -t "stack:$STACK" cf_spec/integration --tag language:"${LANGUAGE}" --tag buildpack_branch:"${BUILDPACK_BRANCH}"
  fi
popd
