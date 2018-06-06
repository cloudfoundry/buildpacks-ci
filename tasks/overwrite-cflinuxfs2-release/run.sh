#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Overwriting BOSH release $ROOTFS_RELEASE"

release_dir=cflinuxfs2-release
version="212.0.$(date +"%s")"

pushd $release_dir
  for name in $( bosh2 blobs | grep -- 'rootfs/cflinuxfs2-*' | awk '{print $1}' ); do
    bosh2 remove-blob "$name"
  done

  blob="../stack-s3/*.tar.gz"

  # shellcheck disable=SC2086
  bosh2 -n add-blob "$blob" "rootfs/$(basename $blob)"

  echo "Running 'bosh create release' in $release_dir"

  bosh2 create-release --force --tarball "dev_releases/$ROOTFS_RELEASE/$ROOTFS_RELEASE-$version.tgz" --name "$ROOTFS_RELEASE" --version "${version}"
popd

cat <<EOF > ${release_dir}/use-dev-release-opsfile.yml
---
- type: replace
  path: /releases/name=cflinuxfs2
  value:
    name: cflinuxfs2
    version: ${version}
EOF

echo "rsyncing $release_dir to ${release_dir}-artifacts"

rsync -a $release_dir/ ${release_dir}-artifacts
