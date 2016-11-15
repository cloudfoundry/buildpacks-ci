#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd cflinuxfs2-rootfs-release
  export BUNDLE_GEMFILE=cf.Gemfile
  bundle install --jobs="$(nproc)" --no-cache

  bundle exec buildpack-build cf_spec --host="$DEPLOYMENT_NAME.$BOSH_LITE_DOMAIN_NAME" --no-build --no-upload

  # Ensure stacks-nc CF does not have multiple orgs when targeting for CATS
  cf delete-org -f pivotal
popd
