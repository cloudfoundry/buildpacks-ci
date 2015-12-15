#!/bin/bash
set -e

version=$(cat version/number)

pushd stacks-release

rm config/blobs.yml
bosh -n add blob ../stack-s3/cflinuxfs2-*.tar.gz rootfs
bosh -n upload blobs

git add config/blobs.yml
git commit -m "Updating blobs stack $version"

bosh -n create release --final --version $version --name stack --force
git add releases/stack/stack-$version.yml releases/stack/index.yml
git commit -m "Final release $version"

popd
