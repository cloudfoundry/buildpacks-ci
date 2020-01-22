#!/usr/bin/env bash

set -euo pipefail

cp -r buildpack/. artifacts

buildpack_toml="$(cat "$PWD/buildpack/buildpack.toml")"
sdk_version="$(cat "$PWD/source/data.json" | jq -r .version.ref)"
output_dir="$PWD/artifacts"
runtime_version="$(cat "$PWD/source/runtime_version")"

pushd "buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table" > /dev/null
  go run . \
    --buildpack-toml "$buildpack_toml" \
    --sdk-version "$sdk_version" \
    --output-dir "$output_dir"\
    --runtime-version "$runtime_version"
popd > /dev/null
