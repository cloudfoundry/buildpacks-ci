#!/usr/bin/env bash

set -euo pipefail

cp -r buildpack/. artifacts

dependency_builds_config="$(cat "$PWD/go/src/github.com/cloudfoundry/buildpacks-ci/pipelines/config/dependency-builds.yml")"
buildpack_toml="$(cat "$PWD/buildpack/buildpack.toml")"
source_data="$(cat "$PWD/source/data.json")"
binary_builds_path="$PWD/builds/binary-builds-new"
output_dir="$PWD/artifacts"

pushd "buildpacks-ci/tasks/cnb/update-cnb-dependency" > /dev/null
  go run . \
    --dependency-builds-config "$dependency_builds_config" \
    --buildpack-toml "$buildpack_toml" \
    --source-data "$source_data" \
    --binary-builds-path "$binary_builds_path" \
    --output-dir "$output_dir" \
    --deprecation-date "$DEPRECATION_DATE" \
    --deprecation-link "$DEPRECATION_LINK" \
    --deprecation-match "$DEPRECATION_MATCH" \
    --version-line "$VERSION_LINE" \
    --versions-to-keep "$VERSIONS_TO_KEEP"
popd > /dev/null
