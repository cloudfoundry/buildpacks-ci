#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

version=$(cat version/number)

pushd "$RELEASE_DIR"

  if [ -n "${SECRET_ACCESS_KEY:+1}" ]; then
    echo "creating private.yml..."
    cat > config/private.yml <<EOF
---
blobstore:
  provider: s3
  options:
    access_key_id: $ACCESS_KEY_ID
    bucket_name: pivotal-offline-buildpacks
    secret_access_key: $SECRET_ACCESS_KEY
    credentials_source: static
EOF
  fi
  rm -rf blobs
  bosh2 blobs | grep -- '-buildpack/.*_buildpack' | awk '{print $1}' | xargs -n1 bosh2 remove-blob

  # we actually want globbing here, so:
  # shellcheck disable=SC2086
  bosh2 -n add-blob ../$BLOB_GLOB "$BLOB_NAME/$(basename ../$BLOB_GLOB)"
  bosh2 -n upload-blobs

  git add config/blobs.yml
  git commit -m "Updating blobs for $RELEASE_NAME $version"

  bosh2 -n create-release --final --version "$version" --name "$RELEASE_NAME"
  git add releases/**/*-"$version".yml releases/**/index.yml
  git add .final_builds/**/index.yml .final_builds/**/**/index.yml
  git commit -m "Final release for $RELEASE_NAME at $version"
popd

rsync -a release/ release-artifacts
