#!/usr/bin/env bash

mkdir -p binaries
tar -xzf lifecycle-tar/lifecycle-binaries-latest.tgz --directory binaries

bins=(analyzer builder detector exporter launcher)

pushd binaries
  touch shasum.txt
  for i in ${bins[@]}; do
      shasum -a 256 ${i} >> shasum.txt
      tar czf v3-${i} ${i}
      tarsha=$(shasum -a 256 v3-${i} | cut -c1-8)
      filename=v3-${i}-$tarsha.tgz
      mv v3-${i} $filename
      aws s3 cp $filename s3://lifecycle-binaries
  done
popd

aws s3 cp binaries/shasum.txt s3://lifecycle-binaries
