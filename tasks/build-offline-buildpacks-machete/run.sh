#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

tag=$(cat blob/tag)
GITHUB_ORG=${GITHUB_ORG:-cloudfoundry}
git clone "https://github.com/$GITHUB_ORG/$LANGUAGE-buildpack.git" source

pushd source
  git checkout "$tag"
  git submodule update --init --recursive
  BUNDLE_GEMFILE=cf.Gemfile bundle
popd

for stack in $CF_STACKS; do
  cp -r source "source-$stack"
  pushd "source-$stack"
    BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager --cached
    echo "stack: $stack" >> manifest.yml
    zip ./*buildpack-cached*.zip manifest.yml
    mv ./*buildpack-cached*.zip $(echo *buildpack-cached*.zip | sed "s/-cached/-cached-${stack}/")
  popd
  mv source-$stack/*_buildpack-cached*.zip buildpack-zip/
done
