#!/bin/bash -l
set -e

pushd deployments-buildpacks
  bundle
  source ./bin/switch $DEPLOYMENT_NAME
popd

cd brats
BUNDLE_GEMFILE=cf.Gemfile bundle install
./bin/tests --language=ruby --host=$DEPLOYMENT_NAME.cf-app.com
