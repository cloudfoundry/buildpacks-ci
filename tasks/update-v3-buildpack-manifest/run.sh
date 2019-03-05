#!/usr/bin/env bash

mkdir -p binaries
tar -xzf lifecycle-tar/lifecycle-binaries-latest.tgz --directory binaries

pushd binaries
  shasum -a 256 analyzer builder detector exporter launcher > shasum.txt
popd

version=$(cat binaries/VERSION)
tar cvf binaries-$version.tgz binaries
