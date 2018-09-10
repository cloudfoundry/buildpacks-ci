#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

version=$(date +%s)

for language in binary dotnet-core go java nodejs php python ruby staticfile; do
  pushd "$language-buildpack-release"
    bosh2 create-release --tarball "../built-buildpacks-artifacts/$language-buildpack-$version.tgz" --name "$language-buildpack" --version "$version"
  popd

  cat <<EOF >> buildpacks-opsfile/use-latest-buildpack-releases.yml
- path: /releases/name=$language-buildpack/version?
  type: replace
  value: $version

EOF
done
