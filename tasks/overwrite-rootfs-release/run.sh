#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Overwriting BOSH release $STACK"

release_dir=rootfs-release
version="212.0.$(date +"%s")"
ubuntu_yymm="18.04"
if [ "${STACK}" = "cflinuxfs4" ]; then
  ubuntu_yymm="22.04"
fi

pushd $release_dir
  for name in $( bosh2 blobs | grep -- "rootfs/$STACK-*" | awk '{print $1}' ); do
    bosh2 remove-blob "$name"
  done

  blob="../stack-s3/*.tar.gz"

  # shellcheck disable=SC2086
  bosh2 -n add-blob $blob "rootfs/$(basename $blob)"

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
- type: replace
  path: /instance_groups/name=api/jobs/name=cloud_controller_ng/properties/cc/stacks
  value:
    - name: $STACK
      description: Cloud Foundry Linux-based filesystem (Ubuntu ${ubuntu_yymm})
- type: replace
  path: /instance_groups/name=diego-cell/jobs/name=rep/properties/diego/rep/preloaded_rootfses
  value:
    - $STACK:/var/vcap/packages/$STACK/rootfs.tar
EOF

echo "rsyncing $release_dir to ${release_dir}-artifacts"

rsync -a "$release_dir/" "${release_dir}-artifacts"
