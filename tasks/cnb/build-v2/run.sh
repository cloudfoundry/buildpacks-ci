#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

readonly ROOT="${PWD}"

function main() {
  local version cached_flag
  version="$( cut -d '-' -f 1 version/version )"

  cached_flag=""
  if [[ -n "${CACHED}" ]]; then
    cached_flag="--cached"
  fi

  mkdir -p "${ROOT}/build"

  pushd "${ROOT}/cnb2cf" > /dev/null || return
    ./scripts/build.sh
  popd > /dev/null || return

  cp "${ROOT}/repo/compat/buildpack.toml" "${ROOT}/build"

  pushd "${ROOT}/build" > /dev/null || return
    "${ROOT}/cnb2cf/build/cnb2cf" package \
      --version "${version}" --stack "cflinuxfs3" "${cached_flag}"
  popd > /dev/null || return

  # shellcheck disable=SC2086
  mv ${ROOT}/build/*-v${version}.zip "${ROOT}/candidate/candidate.zip"
}

main
