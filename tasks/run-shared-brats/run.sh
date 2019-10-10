#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

./cf-space/login

pushd brats
  export BUNDLE_GEMFILE=$PWD/Gemfile

  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  bundle install --deployment
  bundle cache

  if [ -z "${STACK-}" ]; then
    bundle exec rspec cf_spec/integration --tag language:"${LANGUAGE}" --tag buildpack_branch:"${BUILDPACK_BRANCH}"
  else
    bundle exec rspec -t "stack:$STACK" cf_spec/integration --tag language:"${LANGUAGE}" --tag buildpack_branch:"${BUILDPACK_BRANCH}"
  fi
popd
