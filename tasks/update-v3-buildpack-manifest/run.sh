#!/usr/bin/env bash

mkdir -p binaries
tar -xzf lifecycle-tar/lifecycle-binaries-latest.tgz --directory binaries

pushd binaries
  shasum -a 256 analyzer builder detector exporter launcher > shasum.txt
popd

# upload each binary to our s3
# modify manifest with s3 url and sha

