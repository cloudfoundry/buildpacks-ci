#!/bin/bash -eu

readonly FELLER_DIR="${PWD}/feller"

function main() {
  pushd "${FELLER_DIR}" > /dev/null || return
    go test -v ./...
  popd > /dev/null || return
}

main "${@}"
