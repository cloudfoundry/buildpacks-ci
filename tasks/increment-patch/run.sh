#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

readonly ROOT="${PWD}"

function join { local IFS="$1"; shift; echo "$*"; }

function main() {
  local version new_version
  version="$(cat version/version)"

  if [[ ! $version == *"rc"* ]]; then
    IFS='.'

    read -ra ADDR <<< "$version"
    IFS=' '

    ((ADDR[2]=ADDR[2]+1))
    new_version=$(join . "${ADDR[@]}")
    echo -n "$new_version" > version/version
  fi
}

main
