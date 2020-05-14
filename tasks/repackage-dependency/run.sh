#!/bin/bash

set -euo pipefail

name="$(jq -r .source.name source/data.json)"
version="$(jq -r .version.ref source/data.json)"
metadata_file_path="builds/binary-builds-new/$name/$version-cflinuxfs3.json"
filename="binary-builds-new/$name/$version-$STACK_ID.json"
cp "${metadata_file_path}" "${filename}"
git config --global user.email "cf-buildpacks-eng@pivotal.io"
git config --global user.name "CF Buildpacks Team CI Server"
git -C builds add "$filename"
git -C builds commit -m "Build $name - $version - $STACK_ID [#$tracker_story_id]"
