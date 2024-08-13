#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

write_private_yml() {
  if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
    return
  fi

  cat >config/private.yml <<-EOF
---
blobstore:
  options:
    access_key_id: ${AWS_ACCESS_KEY_ID}
    secret_access_key: ${AWS_SECRET_ACCESS_KEY}
EOF

if [ -n "${AWS_ASSUME_ROLE_ARN:-}" ]; then
  cat >>config/private.yml <<-EOF
    assume_role_arn: ${AWS_ASSUME_ROLE_ARN}
EOF
fi
}

version=$(date +%s)

for language in binary dotnet-core go java nodejs php python ruby staticfile; do
  pushd "$language-buildpack-release"
    write_private_yml
    bosh2 create-release --tarball "../built-buildpacks-artifacts/$language-buildpack-$version.tgz" --name "$language-buildpack" --version "$version"
  popd

  cat <<EOF >> buildpacks-opsfile/use-latest-buildpack-releases.yml
- path: /releases/name=$language-buildpack/version?
  type: replace
  value: $version

EOF
done
