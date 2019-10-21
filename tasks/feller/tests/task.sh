#!/bin/bash -eu

function main() {
  pushd "${FELLER_DIR}" > /dev/null || return
    go test -v ./...
  popd > /dev/null || return
}

main "${@}"
