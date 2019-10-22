#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

set -x

pushd cnb2cf
  ./scripts/build.sh
popd

# Cut off the rc part of the version, so that ultimate RC will have the correct version file
version=$( cut -d '-' -f 1 version/version )
pushd repo
  ./scripts/package.sh -a -v "${version}"
  mv repo_*.tgz ../candidate/metacnb-candidate.tgz
  # mkdir .bin
  # mv ../cnb2cf/build/cnb2cf .bin/cnb2cf
  # ./scripts/package-shim -v "${version}"
#  TODO: Configure cnb2cf to output to desired dir
  # mv "nodejs_buildpack-v${version}.zip" ../candidate/candidate.zip
popd
