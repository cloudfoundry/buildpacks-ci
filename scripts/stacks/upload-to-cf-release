#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

mkdir -p cf-release/blobs/rootfs
cp stack-s3/cflinuxfs2-*.tar.gz cf-release/blobs/rootfs/
file_name=$(ls cf-release/blobs/rootfs)
cp receipt-s3/cflinuxfs2_receipt-* cf-release/spec/fixtures/receipts/cflinuxfs2_receipt

pushd cf-release

bundle install --jobs="$(nproc)"

cat <<EOF > config/private.yml
---
blobstore:
  s3:
    access_key_id: $ACCESS_KEY_ID
    secret_access_key: $SECRET_ACCESS_KEY
EOF

cat <<EOF > packages/rootfs_cflinuxfs2/spec
---
name: rootfs_cflinuxfs2
files:
- rootfs/$file_name
EOF

cat <<EOF > packages/rootfs_cflinuxfs2/packaging
set -e -x

echo "Copying rootfs"
cp rootfs/$file_name \${BOSH_INSTALL_TARGET}/cflinuxfs2.tar.gz
EOF

ruby -ryaml -e "
  blobs=YAML.load_file('config/blobs.yml')
  blobs.delete_if { |k,_| k =~ %r{rootfs/cflinuxfs2} }
  File.write('config/blobs.yml', YAML.dump(blobs))
"

bosh -n upload blobs
chmod 644 config/blobs.yml

./scripts/setup-git-hooks

version=$(cat ../version/number)
git commit -m "Bump rootfs to $version" -- config/blobs.yml spec/fixtures/receipts packages/rootfs_cflinuxfs2/packaging packages/rootfs_cflinuxfs2/spec
popd

rsync -a cf-release/ cf-release-artifacts
