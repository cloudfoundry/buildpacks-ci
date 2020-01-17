#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if ! fly -t buildpacks status; then
  if [[ $# != 2 ]] || [[ "$1" == "" ]] || [[ "$2" == "" ]]; then
    fly -t buildpacks login -c https://buildpacks.ci.cf-app.com -b
  else
    fly -t buildpacks login -c https://buildpacks.ci.cf-app.com -u "$1" -p "$2"
  fi
fi

fly -t buildpacks sync
