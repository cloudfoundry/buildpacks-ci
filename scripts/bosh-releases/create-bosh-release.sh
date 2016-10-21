#!/bin/bash
set -ex

version=$(cat version/number)

pushd $RELEASE_DIR

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
  bosh -n add blob ../$BLOB_GLOB $BLOB_NAME
  bosh -n upload blobs

  git add config/blobs.yml
  git commit -m "Updating blobs for $RELEASE_NAME $version"

  bosh -n create release --final --version $version --name $RELEASE_NAME --force
  git add releases/**/*-$version.yml releases/**/index.yml
  git add .final_builds/**/index.yml
  git commit -m "Final release for $BLOB_NAME at $version"
popd

rsync -a release/ release-artifacts
