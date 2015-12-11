#!/bin/bash
set -e

pushd stacks-release

rm config/blobs.yml
bosh -n add blob ../stack-s3/cflinuxfs2-*.tar.gz rootfs
bosh -n upload blobs

popd
