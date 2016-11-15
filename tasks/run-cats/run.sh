#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd deployments-buildpacks
  bundle install --jobs="$(nproc)"
  # shellcheck disable=SC1091
  . ./bin/target_bosh "$DEPLOYMENT_NAME"
popd

if [ "$DIEGO_DOCKER_ON" = "true" ]
then
  cf api "api.$DEPLOYMENT_NAME.$BOSH_LITE_DOMAIN_NAME" --skip-ssl-validation
  cf login -u "$CI_CF_USERNAME" -p "$CI_CF_PASSWORD"
  cf enable-feature-flag diego_docker
fi

bosh run errand acceptance_tests

if [ "$DIEGO_DOCKER_ON" = "true" ]
then
  cf disable-feature-flag diego_docker
fi
