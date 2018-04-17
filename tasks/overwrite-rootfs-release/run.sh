#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Overwriting BOSH release $STACK"

release_dir=rootfs-release
filename=$(< "$release_dir/config/blobs.yml" grep "$STACK" | cut -d ':' -f 1)
version="212.0.$(date +"%s")"

echo "Creating $release_dir directory"

mkdir -p "$release_dir/blobs/$(dirname "$filename")"

echo "Moving stack-s3/*.tar.gz to $release_dir/blobs/$filename"

cp stack-s3/*.tar.gz "$release_dir/blobs/$filename"

pushd "$release_dir"
    echo "Running 'bosh create release' in $release_dir"

    bosh2 create-release --force --tarball "dev_releases/$STACK/$STACK-$version.tgz" --name "$STACK" --version "${version}"
popd

cat <<EOF > ${release_dir}/use-dev-release-opsfile.yml
---
- type: replace
  path: /releases/name=$STACK?
  value:
    name: $STACK
    version: ${version}
EOF

echo "rsyncing $release_dir to ${release_dir}-artifacts"

rsync -a "$release_dir/" "${release_dir}-artifacts"
