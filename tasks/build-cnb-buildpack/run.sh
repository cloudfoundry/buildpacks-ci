#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

set -x

pushd cnb2cf
  go build -o build/cnb2cf ./cmd/cnb2cf/main.go
popd

# Cut off the rc part of the version, so that ultimate RC will have the correct version file
version=$( cut -d '-' -f 1 version/version )
pushd repo
  mkdir .bin
  mv ../cnb2cf/build/cnb2cf .bin/cnb2cf
  ./scripts/package_shim.sh -v "${version}"
#  TODO: Configure cnb2cf to output to desired dir
  mv "nodejs_buildpack-v${version}.zip" ../candidate/candidate.zip
popd