#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

cf api "api.$BOSH_TARGET" --skip-ssl-validation
cf login -u "$CI_CF_USERNAME" -p "$CI_CF_PASSWORD"

cd machete/

./scripts/configure_deployment
