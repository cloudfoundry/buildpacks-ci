#!/usr/bin/env bash

set -euo pipefail

cp -r buildpack/. artifacts

git config --global user.email "paketobuildpacks@gmail.com"
git config --global user.name "paketo-bot"

update_buildpack_toml() {
  buildpack_toml=$1
  buildpack_toml_path=$2

  dependency_builds_config="$(cat "buildpacks-ci/pipelines/config/dependency-builds.yml")"
  source_data="$(cat "source/data.json")"
  binary_builds_path="$PWD/builds/binary-builds-new"
  output_dir="$PWD/artifacts"

  pushd "buildpacks-ci/tasks/cnb/update-cnb-dependency" > /dev/null
    go run . \
      --dependency-builds-config "$dependency_builds_config" \
      --buildpack-toml "$buildpack_toml" \
      --source-data "$source_data" \
      --binary-builds-path "$binary_builds_path" \
      --output-dir "$output_dir" \
      --buildpack-toml-output-path "$buildpack_toml_path" \
      --deprecation-date "$DEPRECATION_DATE" \
      --deprecation-link "$DEPRECATION_LINK" \
      --deprecation-match "$DEPRECATION_MATCH" \
      --version-line "$VERSION_LINE" \
      --versions-to-keep "$VERSIONS_TO_KEEP"
  popd > /dev/null
}

if [[ "$COMPAT_ONLY" != "true" ]]; then
  buildpack_toml="$(cat "buildpack/buildpack.toml")"
  buildpack_toml_path="buildpack.toml"

  update_buildpack_toml "$buildpack_toml" "$buildpack_toml_path"
fi

if [[ -f buildpack/compat/buildpack.toml ]]; then
  buildpack_toml="$(cat "buildpack/compat/buildpack.toml")"
  buildpack_toml_path="compat/buildpack.toml"

  update_buildpack_toml "$buildpack_toml" "$buildpack_toml_path"
fi
