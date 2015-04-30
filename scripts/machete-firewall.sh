#!/bin/bash

pushd deployments-buildpacks
  bundle
  source ./bin/switch bp-ci-8
popd

cd machete-firewall-tests
../ci-tools/buildpack-builds --host=bp-ci-8.cf-app.com
