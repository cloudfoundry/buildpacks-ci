#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

cd blob
mkdir source
tar zxf source.tar.gz -C source --strip-components=1

cd source
BUNDLE_GEMFILE=cf.Gemfile bundle
BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager --cached

# shellcheck disable=SC2035
mv *_buildpack-cached*.zip ../../buildpack-zip/
