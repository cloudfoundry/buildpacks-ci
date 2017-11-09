#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

./cf-space/login
SPACE=$(cat cf-space/name)
CF_HOST=$(cf api | grep https | sed 's/.*https:\/\/api\.//')

cd buildpack

../buildpacks-ci/tasks/run-buildpack-shared-specs/check-unsupported-manifest.rb
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
  bundle exec buildpack-build --uncached --stack="$stack" --host="$CF_HOST" --shared-host --integration-space="$SPACE"
  bundle exec buildpack-build --cached --stack="$stack" --host="$CF_HOST" --shared-host --integration-space="$SPACE"
done
