#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

version="$(cat version/version)"
export GOPATH=$PWD/go

get_url() {
local os="$1"
local ext
if [[ "$os" == "windows" ]]; then
  ext="zip"
  else
  ext="tgz"
fi
echo https://github.com/cloudfoundry/stack-auditor/releases/download/v$version/stack-auditor-$version-$os.$ext
}


calculate_checksum() {
    local os="$1"
    local url=$(get_url $os)
    local filename=$(basename $url)

    wget "$url"

    local checksum="$(shasum -a 1 $filename| cut -d " " -f 1)"
    echo "$checksum"
}


pushd go/src/code.cloudfoundry.org/cli-plugin-repo
cat <<EOF >> repo-index.yml
- authors:
  - contact: cf-buildpacks-eng@pivotal.io
    name: Pivotal Buildpacks team
  binaries:
  - checksum: $(calculate_checksum darwin)
    platform: osx
    url: $(get_url darwin)
  - checksum: $(calculate_checksum windows)
    platform: win64
    url: $(get_url windows)
  - checksum: $(calculate_checksum linux)
    platform: linux64
    url: $(get_url linux)
  company: Pivotal
  created: 2019-07-25T15:32:00Z
  description: Provides commands for listing apps and their stacks, migrating apps
    to a new stack, and deleting a stack
  homepage: https://github.com/cloudfoundry/stack-auditor
  name: stack-auditor
  updated: $(date +"%Y-%m-%dT%H:%M:%SZ")
  version: $version
EOF

go run sort/main.go repo-index.yml

popd

