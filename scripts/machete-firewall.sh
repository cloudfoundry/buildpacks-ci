#!/bin/bash
set -e

pushd deployments-buildpacks
  bundle
  source ./bin/switch $DEPLOYMENT_NAME
popd

cd machete-firewall-tests
../ci-tools/buildpack-builds --host=$DEPLOYMENT_NAME.cf-app.com
