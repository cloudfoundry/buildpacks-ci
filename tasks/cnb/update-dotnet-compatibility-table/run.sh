#!/usr/bin/env bash

set -euo pipefail

cp -r buildpack/. artifacts

buildpack_toml="$(cat "buildpack/buildpack.toml")"
sdk_version="$(jq -r .version.ref "source/data.json")"
runtime_version="$(cat "source/runtime_version")"
output_dir="$PWD/artifacts"

pushd "buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table" > /dev/null
  go run . \
    --buildpack-toml "$buildpack_toml" \
    --sdk-version "$sdk_version" \
    --output-dir "$output_dir"\
    --runtime-version "$runtime_version"
popd > /dev/null
