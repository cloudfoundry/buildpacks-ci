#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

tag=$(cat blob/tag)
GITHUB_ORG=${GITHUB_ORG:-cloudfoundry}
git clone "https://github.com/$GITHUB_ORG/$LANGUAGE-buildpack.git" source

pushd source
  source .envrc

  git checkout "$tag"
  git submodule update --init --recursive

  ./scripts/install_tools.sh

  for stack in $CF_STACKS; do
      if [[ "$stack" == "any" ]]; then
        buildpack-packager build --cached --any-stack
      else
        buildpack-packager build --cached "--stack=$stack"
      fi
  done
popd

# shellcheck disable=SC2035
mv source/*_buildpack-cached*.zip buildpack-zip/
