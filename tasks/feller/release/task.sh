#!/bin/bash -eu

readonly FELLER_DIR="${PWD}/feller"

function main() {
  pushd "${FELLER_DIR}" > /dev/null || return
    go build -o feller main.go
  popd > /dev/null || return
}

main "${@}"
