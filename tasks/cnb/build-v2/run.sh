#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

readonly ROOT="${PWD}"

function main() {
  ls -al "${ROOT}/cnb-tarball"
  # Cut off the rc part of the version, so that ultimate RC will have the correct version file
  local version
  version=$( cut -d '-' -f 1 version/version )

  mkdir -p "${ROOT}/build"

  # shellcheck disable=SC2086
  tar xzvf ${ROOT}/cnb-tarball/*.tgz -C "${ROOT}/build"

  pushd "${ROOT}/cnb2cf" > /dev/null || return
    ./scripts/build.sh
  popd > /dev/null || return

  pushd "${ROOT}/build" > /dev/null || return
    "${ROOT}/cnb2cf/build/cnb2cf" package \
      --version "${version}" --stack "cflinuxfs3"
  popd > /dev/null || return

  # shellcheck disable=SC2086
  mv ${ROOT}/build/*-v${version}.zip "${ROOT}/candidate/candidate.zip"
}

main
