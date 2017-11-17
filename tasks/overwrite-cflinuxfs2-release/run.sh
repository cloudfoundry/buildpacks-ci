#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Overwriting BOSH release $ROOTFS_RELEASE"

release_dir=cflinuxfs2-release
filename=$(< cflinuxfs2-release/config/blobs.yml grep cflinuxfs2 | cut -d ':' -f 1)
version="212.0.$(date +"%s")"

echo "Creating $release_dir directory"

mkdir -p "$release_dir/blobs/$(dirname "$filename")"

echo "Moving stack-s3/*.tar.gz to $release_dir/blobs/$filename"

cp stack-s3/*.tar.gz "$release_dir/blobs/$filename"

pushd $release_dir
    echo "Running 'bosh create release' in $release_dir"

    bosh create release --force --with-tarball --name "$ROOTFS_RELEASE" --version "${version}"
    ./scripts/generate-bosh-lite-manifest
popd

echo "rsyncing $release_dir to ${release_dir}-artifacts"

rsync -a $release_dir/ ${release_dir}-artifacts

cat <<EOF > ${release_dir}-artifacts/use-dev-release-opsfile.yml
---
- type: replace
  path: /releases/name=cflinuxfs2
  value:
    name: cflinuxfs2
    version: ${version}
EOF
