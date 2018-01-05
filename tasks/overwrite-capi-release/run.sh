#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Overwriting BOSH release capi"

version="212.0.$(date +"%s")"
gem install bundler -v 1.15.4

rsync -a capi-release/ capi-release-artifacts/

cd capi-release-artifacts
echo "Running 'bosh create release' in capi-release"

bosh2 create-release --force --tarball "dev_releases/capi/capi-$version.tgz" --name capi --version "${version}"

cat <<EOF > use-dev-release-opsfile.yml
---
- type: replace
  path: /releases/name=capi
  value:
    name: capi
    version: ${version}
EOF
