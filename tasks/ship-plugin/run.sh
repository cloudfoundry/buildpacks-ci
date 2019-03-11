#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

export GOBIN=$PWD/.bin
export PATH=$GOBIN:$PATH

OSes=(linux darwin windows)

version=$(cat version/version)
pushd stack-auditor
  for os in "${OSes[@]}"; do
    binary="stack-auditor-$version-${os}"
    artifacts="../plugin-artifacts/"
    GOOS="${os}" go build -o "$artifacts$binary" -ldflags="-s -w" github.com/cloudfoundry/stack-auditor
    pushd $artifacts
      if [ "${os}" == "windows" ]; then
        zip "$binary".zip "$binary"
      else
        tar czf "$binary".tgz "$binary"
      fi
    popd
  done
popd

echo "v$version" > plugin-artifacts/name
echo "v$version" > plugin-artifacts/tag
echo "Fill this out" > plugin-artifacts/body

