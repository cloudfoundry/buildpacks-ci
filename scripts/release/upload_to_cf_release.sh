#!/bin/bash -l
set -e

export TMPDIR=/tmp
export BUILDPACK_VERSION=`cat buildpack/VERSION`
export BUILDPACK_LANGUAGE=`ruby -ryaml -e 'puts YAML.load_file("buildpack/manifest.yml")["language"]'`

./buildpacks-ci/scripts/release/finalize-buildpack

gem install bosh_cli --no-rdoc --no-ri

cat <<EOF > cf-release/config/private.yml
---
blobstore:
  s3:
    access_key_id: $ACCESS_KEY_ID
    secret_access_key: $SECRET_ACCESS_KEY
EOF

export GITHUB_CREDENTIALS=$GITHUB_USER:$GITHUB_PASSWORD

pushd cf-release
  ../buildpacks-ci/scripts/release/add_to_cf_release ../pivotal-buildpacks-cached/*_buildpack-cached-v*.zip
popd

rsync -a cf-release/ cf-release-artifacts
