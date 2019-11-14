#!/usr/bin/env bash
# ./fly-login username password

set -o errexit
set -o nounset
set -o pipefail

if (( $# != 2 ))
then
  fly -t buildpacks login -c https://buildpacks.ci.cf-app.com
else
  fly -t buildpacks login -c https://buildpacks.ci.cf-app.com -u "$1" -p "$2"
fi

fly -t buildpacks sync
