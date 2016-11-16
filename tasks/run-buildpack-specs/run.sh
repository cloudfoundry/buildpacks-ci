#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

DEPLOYMENT_NAME=$(cat cf-environments/name)

cd buildpack

../buildpacks-ci/tasks/run-buildpack-specs/check-unsupported-manifest.rb
../buildpacks-ci/scripts/start-docker

# for the PHP buildpack
if [ -e run_tests.sh ]; then
  export TMPDIR
  TMPDIR=$(mktemp -d)
  pip install -r requirements.txt
fi

export BUNDLE_GEMFILE=cf.Gemfile

if [ ! -z "$RUBYGEM_MIRROR" ]
then
  bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
fi

bundle install --jobs="$(nproc)" --no-cache

for stack in $STACKS; do
  bundle exec buildpack-build --uncached --stack="$stack" --host="$DEPLOYMENT_NAME.$BOSH_LITE_DOMAIN_NAME"
  bundle exec buildpack-build --cached --stack="$stack" --host="$DEPLOYMENT_NAME.$BOSH_LITE_DOMAIN_NAME"
done
