#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

export GOPATH=$PWD/buildpack
export GOBIN=/usr/local/bin

if [ "$LANGUAGE" = "go" ]; then
  update_dir="src/golang"
elif [ "$LANGUAGE" = "staticfile" ]; then
  update_dir="src/staticfile"
elif [ "$LANGUAGE" = "nodejs" ]; then
  update_dir="src/nodejs"
else
  update_dir="src/compile"
fi

pushd buildpack
  pushd "$update_dir"
    if [ -d vendor/github.com/golang/mock/mockgen ]; then
      pushd vendor/github.com/golang/mock/mockgen
        go install
      popd
    fi
    pushd vendor/github.com/onsi/ginkgo/ginkgo
      go install
    popd

    if [ -f Gopkg.toml ]; then
      go get github.com/golang/dep/cmd/dep
      dep ensure --update
    else
      go get github.com/FiloSottile/gvt
      gvt update github.com/cloudfoundry/libbuildpack
    fi

    go generate || true
    [ -d compile ] && (cd compile && (go generate || true))
    [ -d hooks ] && (cd hooks && (go generate || true))
    [ -d supply ] && (cd supply && (go generate || true))
    [ -d finalize ] && (cd finalize && (go generate || true))

    ginkgo -r -skipPackage=integration
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
