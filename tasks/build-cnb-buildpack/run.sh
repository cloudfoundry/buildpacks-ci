#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

set -x

pushd cnb2cf
  go build -o build/cnb2cf ./cmd/cnb2cf/main.go
popd

version=$(cat version/version)
pushd repo
  mkdir .bin
  mv ../cnb2cf/build/cnb2cf .bin/cnb2cf
  ./scripts/package.sh -v "${version}"
#  TODO: Configure cnb2cf to output to desired dir
  mv "nodejs_buildpack-v${version}.zip" ../candidate/candidate.zip
popd