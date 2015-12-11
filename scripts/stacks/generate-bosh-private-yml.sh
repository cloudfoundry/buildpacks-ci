#!/bin/bash
set -e

pushd stacks-release

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

popd
