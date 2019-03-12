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

pushd stack-auditor
	latest=$(git describe --tags --abbrev=0 2>/dev/null)
	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		gitlog=$(git log --pretty=format:"* %s")
	else
		gitlog=$(git log $latest..HEAD --pretty=format:"* %s")
	fi
popd

printf "$gitlog" > release-artifacts/body

