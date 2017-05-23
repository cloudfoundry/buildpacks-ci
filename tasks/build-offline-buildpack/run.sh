#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

tag=$(cat blob/tag)
git clone "https://github.com/cloudfoundry/$LANGUAGE-buildpack.git" source

pushd source
  git checkout "$tag"
  git submodule update --init --recursive

  BUNDLE_GEMFILE=cf.Gemfile bundle
  BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager --cached
popd

# shellcheck disable=SC2035
mv source/*_buildpack-cached*.zip buildpack-zip/
