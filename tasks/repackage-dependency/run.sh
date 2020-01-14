#!/bin/bash

set -euo pipefail

name="$(jq -r .source.name source/data.json)"
version="$(jq -r .version.ref source/data.json)"
tracker_story_id="$(jq -r .tracker_story_id "builds/binary-builds-new/$name/$version.json")"
path=
source_url=

case "$name" in
  go)
    path="go$version.linux-amd64.tar.gz"
    source_url="https://dl.google.com/go/$path"
    ;;
  node)
    path="node-v$version=linux-x64.tar.gz"
    source_url="https://nodejs.org/dist/v$version/$path"
    ;;
  *)
    echo "$name is not supported."
    exit 1
    ;;
esac

wget "$source_url"
source_sha="$(sha256sum "$path" | cut -d ' ' -f1)"

dir="$(mktemp -d)"
tar -C "$dir" --transform 's:^\./::' --strip-components 1 -xf "$path"
tar -C "$dir" -czf "$path" .

sha="$(sha256sum "$path" | cut -d ' ' -f1)"
new_file_path="$name-$version-$STACK-${sha:0:8}.tgz"
mv "$path" "artifacts/$new_file_path"

filename="binary-builds-new/$name/$version-$STACK.json"
cat >"builds/$filename" <<-EOF
{
  "tracker_story_id": $tracker_story_id,
  "version": "$version",
  "url": "https://buildpacks.cloudfoundry.org/dependencies/$name/$new_file_path",
  "sha256": "$sha",
  "source": {
    "url": "$source_url",
    "sha256": "$source_sha"
  }
}
EOF

git config --global user.email "cf-buildpacks-eng@pivotal.io"
git config --global user.name "CF Buildpacks Team CI Server"
git -C builds add "$filename"
git -C builds commit -m "Build $name - $version - $STACK_ID [#$tracker_story_id]"
