#!/bin/bash -l
set -e

export TMPDIR=$(mktemp -d)
DEPLOYMENT_NAME=`cat cf-environments/name`

pushd deployments-buildpacks
  bundle
  source ./bin/switch $DEPLOYMENT_NAME
popd

cd php-buildpack
pip install -r requirements.txt 

./run_tests.sh

for stack in $STACKS; do
  ../ci-tools/buildpack-build --uncached --stack=$stack --host=$DEPLOYMENT_NAME.cf-app.com
  ../ci-tools/buildpack-build --cached --stack=$stack --host=$DEPLOYMENT_NAME.cf-app.com
done
