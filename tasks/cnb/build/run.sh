#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

set -x

# Cut off the rc part of the version, so that ultimate RC will have the correct version file
version=$( cut -d '-' -f 1 version/version )
pushd repo
  ./scripts/package.sh -a -v "${version}"
  mv repo_*.tgz ../candidate/metacnb-candidate.tgz
popd
