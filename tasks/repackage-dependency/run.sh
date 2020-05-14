#!/bin/bash

set -euo pipefail

name="$(jq -r .source.name source/data.json)"
version="$(jq -r .version.ref source/data.json)"
tracker_story_id="$(jq -r .tracker_story_id "builds/binary-builds-new/$name/$version.json")"

if [ "${ANY_STACK}" == "true" ]; then
  metadata_file_path="builds/binary-builds-new/$name/$version-any-stack.json"
else
  metadata_file_path="builds/binary-builds-new/$name/$version-cflinuxfs3.json"
fi

git_filename="binary-builds-new/$name/$version-$STACK.json"
full_filename="builds/$git_filename"
cp "${metadata_file_path}" "${full_filename}"
git config --global user.email "cf-buildpacks-eng@pivotal.io"
git config --global user.name "CF Buildpacks Team CI Server"
git -C builds add "$git_filename"
git -C builds commit -m "Build $name - $version - $STACK [#$tracker_story_id]"
