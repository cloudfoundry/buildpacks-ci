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
    artifacts="../release-artifacts/"
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

echo "v$version" > release-artifacts/name
echo "v$version" > release-artifacts/tag
echo "Fill this out" > release-artifacts/body

