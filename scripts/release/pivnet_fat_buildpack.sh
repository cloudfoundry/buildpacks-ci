#!/bin/bash -l
set -e

cd buildpack

../ci-tools/extract-recent-changes

export BUNDLE_GEMFILE=cf.Gemfile
bundle install
bundle exec buildpack-packager cached --use-custom-manifest=manifest-including-unsupported.yml

# ../ci-tools/upload_to_pivnet \
  # "$PIVNET_PRODUCT_NAME" \
  # `cat VERSION` \
  # *_buildpack-cached-v*.zip \
  # RECENT_CHANGES < /dev/null
