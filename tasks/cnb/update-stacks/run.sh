#!/usr/bin/env bash

set -euo pipefail

update_buildpack_toml() {
  buildpack_toml=$1
  buildpack_toml_path=$2

  dependency_builds_config="$(cat "buildpacks-ci/pipelines/config/dependency-builds.yml")"
  output_dir="$PWD/buildpack"

  pushd "buildpacks-ci/tasks/cnb/update-stacks" > /dev/null
    go run . \
      --dependency-builds-config "$dependency_builds_config" \
      --buildpack-toml "$buildpack_toml" \
      --output-dir "$output_dir" \
      --buildpack-toml-output-path "$buildpack_toml_path"
  popd > /dev/null
}

update_buildpack_toml "$(cat "buildpack/buildpack.toml")" "buildpack.toml"

if [[ -f buildpack/compat/buildpack.toml ]]; then
  update_buildpack_toml "$(cat "buildpack/compat/buildpack.toml")" "compat/buildpack.toml"
fi
