#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

export GOPATH=$PWD/buildpack
export GOBIN=/usr/local/bin

update_dir="src/compile"

pushd buildpack
	pushd "$update_dir"
	  go get github.com/golang/dep/cmd/dep
		go get github.com/golang/mock/mockgen
		go get github.com/onsi/ginkgo/ginkgo

		dep ensure
		dep ensure -update

		go generate || true
		ginkgo
	popd

	git add "$update_dir"

	set +e
		git diff --cached --exit-code
		no_changes=$?
	set -e

	if [ $no_changes -ne 0 ]
	then
		git commit -m "Update buildpackapplifecycle"
	else
		echo "buildpackapplifecycle is up to date"
	fi
popd

rsync -a buildpack/ buildpack-artifacts
