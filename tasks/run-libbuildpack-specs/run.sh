#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH
mkdir -p $GOPATH

CF_DIR=$GOPATH/src/github.com/cloudfoundry/
mkdir -p $CF_DIR

echo "Moving libbuildpack onto the gopath..."
cp -R libbuildpack $CF_DIR

cd $CF_DIR/libbuildpack

go get -t ./...
go get github.com/onsi/ginkgo/ginkgo
ginkgo -r
