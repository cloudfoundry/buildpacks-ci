#!/usr/bin/env bash

set -euo pipefail

cp -r buildpack/. artifacts

buildpack_toml="$(cat "buildpack/buildpack.toml")"
sdk_version="$(jq -r .version.ref "source/data.json")"
runtime_version="$(cat "source/runtime_version")"
output_dir="$PWD/artifacts"

minor_version="$(echo "$runtime_version" | cut -d '.' -f1-2)"

pushd "buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table" > /dev/null
  curl -s -O "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/$minor_version/releases.json"

  go run . \
    --buildpack-toml "$buildpack_toml" \
    --sdk-version "$sdk_version" \
    --output-dir "$output_dir"\
    --runtime-version "$runtime_version" \
    --releases-json-path "releases.json"
popd > /dev/null
