#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

version=$(date +%s)

for language in binary dotnet-core go java nodejs php python ruby staticfile; do
  pushd "$language-buildpack-release"
    #TODO: We do not need to do this when we are using online releases
    cat > config/private.yml <<EOF
---
blobstore:
  provider: s3
  options:
    access_key_id: $ACCESS_KEY_ID
    bucket_name: pivotal-offline-buildpacks
    secret_access_key: $SECRET_ACCESS_KEY
    credentials_source: static
EOF
    bosh2 create-release --tarball "../built-buildpacks-artifacts/$language-$version.tgz" --name "$language" --version "$version"
  popd

  cat <<EOF >> buildpacks-opsfile/use-latest-buildpack-releases.yml
- path: /releases/name=$language-buildpack/version?
  type: replace
  value: $version

EOF
done

