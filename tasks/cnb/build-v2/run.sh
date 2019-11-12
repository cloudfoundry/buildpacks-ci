#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

set -x

readonly ROOT="${PWD}"

function main() {
  ls -al "${ROOT}/cnb-tarball"
  # Cut off the rc part of the version, so that ultimate RC will have the correct version file
  local version
  version=$( cut -d '-' -f 1 version/version )

  mkdir -p "${ROOT}/build"
  tar xzvf ${ROOT}/cnb-tarball/*.tgz -C "${ROOT}/build"

  pushd "${ROOT}/cnb2cf" > /dev/null || return
    ./scripts/build.sh
  popd > /dev/null || return

  pushd "${ROOT}/build" > /dev/null || return
    "${ROOT}/cnb2cf/build/cnb2cf" package \
      --version "${version}" --stack "cflinuxfs3"
  popd > /dev/null || return

  mv ${ROOT}/build/*-v${version}.zip "${ROOT}/candidate/candidate.zip"
}

main
