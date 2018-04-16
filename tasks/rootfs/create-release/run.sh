#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

set -x

stacks_version=$(cat version/number)
bosh_release_version=$(cat version/number)

pushd release
  set +x
  if [ -n "${SECRET_ACCESS_KEY:+1}" ]; then
  echo "creating private.yml..."
  cat > config/private.yml <<EOF
---
blobstore:
  options:
    access_key_id: $ACCESS_KEY_ID
    secret_access_key: $SECRET_ACCESS_KEY
EOF
  fi
  set -x

  rm -f config/blobs.yml
  touch config/blobs.yml

  # shellcheck disable=SC2086
  BLOB="$(ls ../$BLOB_GLOB)"

  if [ ! -f "$BLOB" ] ; then
    echo "$STACK blob not found at $BLOB_GLOB"
    exit 1
  fi

  bosh2 -n add-blob "$BLOB" "$BLOB_NAME/$(basename "$BLOB")"
  bosh2 -n upload-blobs

  git add config/blobs.yml
  git commit -m "Updating blobs for $RELEASE_NAME bosh release version $bosh_release_version"

  bosh2 -n create-release --final --version "$bosh_release_version" --name "$RELEASE_NAME" --tarball "releases/$RELEASE_NAME/$RELEASE_NAME-$bosh_release_version.tgz"
  git add .final_builds "releases/**/*-$bosh_release_version.yml" releases/**/index.yml
  git commit -m "Final $RELEASE_NAME bosh release version $bosh_release_version, containing $STACK version $stacks_version"
popd

rsync -a release/ release-artifacts
