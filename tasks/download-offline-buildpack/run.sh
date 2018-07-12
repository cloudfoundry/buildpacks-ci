#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

ls -l pivnet-production

pushd pivnet-production
    echo "stack: cflinuxfs2" > manifest.yml
    old_name="$(echo ./*buildpack-offline*.zip)"
    zip "$old_name" manifest.yml
    new_name="${old_name//-offline/-offline-$CF_STACK}"
    mv "$old_name" "$new_name"
popd

# shellcheck disable=SC2035
mv pivnet-production/java-buildpack-offline*.zip buildpack-zip/
