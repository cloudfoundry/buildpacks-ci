#!/usr/bin/env bash
set -e

pushd pivotal-buildpacks-cached
filename="`basename *_buildpack-cached-v*.zip`"
checksum="${filename}.CHECKSUM.txt"
echo $checksum
echo "md5: `md5sum $filename`" > $checksum
echo "sha256: `sha256sum $filename`" >> $checksum
cat $checksum >> ../buildpack/RECENT_CHANGES
popd
