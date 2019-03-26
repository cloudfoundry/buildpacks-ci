#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

ls -l pivnet-production

pushd pivnet-production
    old_name="$(echo ./*buildpack-offline*.zip)"
    # shellcheck disable=SC2128
    for stack in $CF_STACKS; do
      echo "stack: $stack" > manifest.yml
      new_name="${old_name//-offline/-offline-$stack}"
      cp "$old_name" "$new_name"
      zip "$new_name" manifest.yml
      rm manifest.yml
    done
    rm "$old_name"
popd

# shellcheck disable=SC2035
mv pivnet-production/java-buildpack-offline*.zip buildpack-zip-stack0/
mv pivnet-production/version buildpack-zip-stack0/
