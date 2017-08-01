#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

DEPLOYMENT_NAME=$(cat cf-environments/name)
cf login -a "api.$DEPLOYMENT_NAME.$BOSH_LITE_DOMAIN_NAME" -u admin -p "$CF_PASSWORD" -o integration -s integration --skip-ssl-validation
cf create-org integration || true
cf create-space integration -o integration || true
cf target -o integration -s integration

./buildpacks-ci/scripts/start-docker

cd buildpack

export GOPATH=$PWD
export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

./scripts/unit.sh

CACHED=true  ./scripts/integration.sh
CACHED=false ./scripts/integration.sh
