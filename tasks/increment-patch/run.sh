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
    new_version="$(join . "${ADDR[@]}")-rc.1"
    echo -n "$new_version" > version/version
    echo "incremented version to $new_version"
  else
    local version_base rc_num next_rc_num
    version_base="$( cut -d '-' -f 1 version/version )"
    rc_num="$( cut -d '.' -f 4 version/version )"
    next_rc_num=$((rc_num+1))

    echo -n "$version_base-rc.$next_rc_num" > version/version
  fi
}

main
