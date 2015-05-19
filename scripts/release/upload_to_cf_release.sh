#!/bin/bash
set -e

export TMPDIR=/tmp
export BUILDPACK_VERSION=`cat buildpack/VERSION`

wget -O- https://github.com/github/hub/releases/download/v2.2.1/hub-linux-amd64-2.2.1.tar.gz | tar xz -C /usr/bin --strip-components=1 hub-linux-amd64-2.2.1/hub

pushd pivotal-buildpacks-cached
ruby <<RUBY
require "fileutils"
Dir.glob("*.zip").map do |filename|
  filename.match(/(.*)_buildpack-cached-v(.*)\+.*.zip/) do |match|
    language = match[1]
    version = match[2]
    FileUtils.mv(filename, "#{language}_buildpack-cached-v#{version}.zip")
  end
end
RUBY
popd

pushd ci-tools
bundle install
popd

cat <<EOF > cf-release/config/private.yml
---
blobstore:
  s3:
    access_key_id: $ACCESS_KEY_ID
    secret_access_key: $SECRET_ACCESS_KEY
EOF

export GITHUB_CREDENTIALS=$GITHUB_USER:$GITHUB_PASSWORD

pushd cf-release
../ci-tools/jenkins_git_credentials add
git config --global user.email "cf-buildpacks-eng@pivotal.io"
git config --global user.name "CF Buildpacks Team CI Server"
../ci-tools/add_to_cf_release ../pivotal-buildpacks-cached/*_buildpack-cached-v*.zip
popd
