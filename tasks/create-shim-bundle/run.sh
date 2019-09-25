#!/bin/bash -l

set -euo pipefail

readonly SHIM_DIR="${PWD}/shim"
readonly ARCHIVE_DIR="${PWD}/archive"
readonly VERSION_DIR="${PWD}/version"

function main() {
    local version sha
    version="$(cat "${VERSION_DIR}/version")"

    pushd "${SHIM_DIR}" > /dev/null || return
        ./scripts/build.sh
    popd > /dev/null || return

    pushd "${SHIM_DIR}/template/bin" > /dev/null || return
        tar czf \
            "${ARCHIVE_DIR}/shim-bundle.tgz" \
            detect supply finalize release
    popd > /dev/null || return

    sha="$(sha256sum "${ARCHIVE_DIR}/shim-bundle.tgz" | cut -d ' ' -f 1)"

    mv "${ARCHIVE_DIR}/shim-bundle.tgz" "${ARCHIVE_DIR}/shim-bundle-${version}-${sha::8}.tgz"
}

main
