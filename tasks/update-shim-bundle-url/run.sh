#!/bin/bash -l

set -euo pipefail

version=$(cat s3/version)
url=$(cat s3/url)
file=$(basename "$url")
echo "https://buildpacks.cloudfoundry.org/dependencies/shim-bundle/$file" > buildpack/SHIM_URL

pushd buildpack
  git add .

  set +e
    git diff --cached --exit-code
    no_changes=$?
  set -e

  if [ $no_changes -ne 0 ]
  then
    git commit -m "Update shim bundle version to $version"
  else
    echo "create template is up to date"
  fi
popd