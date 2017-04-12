#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

export GOPATH=$PWD/buildpack
export GOBIN=/usr/local/bin



if [ "$LANGUAGE" = "go" ]; then
  update_dir="src/golang"
else
  update_dir="src/compile"
fi

pushd buildpack
	pushd "$update_dir"
		go get github.com/FiloSottile/gvt
		go get github.com/golang/mock/gomock
		go get github.com/golang/mock/mockgen
		go get github.com/onsi/ginkgo/ginkgo
		go get github.com/onsi/gomega

		gvt update github.com/cloudfoundry/libbuildpack
		go generate
		ginkgo -r
	popd

	git add "$update_dir"

	set +e
		git diff --cached --exit-code
		no_changes=$?
	set -e

	if [ $no_changes -ne 0 ]
	then
		git commit -m "Update libbuildpack"
	else
		echo "libbuildpack is up to date"
	fi
popd

rsync -a buildpack/ buildpack-artifacts
