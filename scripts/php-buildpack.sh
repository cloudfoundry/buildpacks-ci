#!/bin/bash -l
set -e

export TMPDIR=$(mktemp -d)
DEPLOYMENT_NAME=`cat cf-environments/name`

pushd deployments-buildpacks
  bundle
  source ./bin/switch $DEPLOYMENT_NAME
popd

cd php-buildpack

../buildpacks-ci/scripts/check-unsupported-manifest

pip install -r requirements.txt 

./run_tests.sh

export BUNDLE_GEMFILE=cf.Gemfile
bundle -j4 --no-cache

for stack in $STACKS; do
  bundle exec buildpack-build --uncached --stack=$stack --host=$DEPLOYMENT_NAME.cf-app.com
  bundle exec buildpack-build --cached --stack=$stack --host=$DEPLOYMENT_NAME.cf-app.com
done
