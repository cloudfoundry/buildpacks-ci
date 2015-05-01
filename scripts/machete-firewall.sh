#!/bin/bash -l
set -e

pushd deployments-buildpacks
  bundle
  source ./bin/switch $DEPLOYMENT_NAME
popd

cd machete-firewall-tests

for stack in $STACKS; do
  ../ci-tools/buildpack-build --uncached --stack=$stack --host=$DEPLOYMENT_NAME.cf-app.com
  ../ci-tools/buildpack-build --cached --stack=$stack --host=$DEPLOYMENT_NAME.cf-app.com
done
