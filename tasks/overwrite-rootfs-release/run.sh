#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Overwriting BOSH release $STACK"

release_dir=rootfs-release
version="212.0.$(date +"%s")"

pushd $release_dir
  for name in $( bosh blobs | grep -- "rootfs/$STACK-*" | awk '{print $1}' ); do
    bosh remove-blob "$name"
  done

  blob="../stack-s3/*.tar.gz"

  # shellcheck disable=SC2086
  bosh -n add-blob $blob "rootfs/$(basename $blob)"

  echo "Running 'bosh create release' in $release_dir"

  bosh create-release --force --tarball "dev_releases/$STACK/$STACK-$version.tgz" --name "$STACK" --version "${version}"
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
