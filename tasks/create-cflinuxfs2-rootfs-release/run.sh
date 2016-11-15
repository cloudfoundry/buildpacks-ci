#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

set -x

stacks_version=$(cat version/number)
bosh_release_version=$(cat cflinuxfs2-rootfs-release-version/number)

pushd "$RELEASE_DIR"
  if [ -n "${SECRET_ACCESS_KEY:+1}" ]; then
  echo "creating private.yml..."
  cat > config/private.yml <<EOF
---
blobstore:
  s3:
    access_key_id: $ACCESS_KEY_ID
    secret_access_key: $SECRET_ACCESS_KEY
EOF
  fi

  rm -f config/blobs.yml
  # here, we actually want globbing, so:
  # shellcheck disable=SC2086
  bosh -n add blob ../$BLOB_GLOB "$BLOB_NAME"
  bosh -n upload blobs

  git add config/blobs.yml
  git commit -m "Updating blobs for $RELEASE_NAME bosh release version $bosh_release_version"

  bosh -n create release --final --version "$bosh_release_version" --name "$RELEASE_NAME" --with-tarball
  git add .final_builds "releases/**/*-$bosh_release_version.yml" releases/**/index.yml
  git commit -m "Final $RELEASE_NAME bosh release version $bosh_release_version, containing cflinuxfs2 version $stacks_version"
popd

rsync -a "$RELEASE_DIR/" release-artifacts
