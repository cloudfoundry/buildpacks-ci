#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

if [[ ${DOCKER_START} == "true" ]]; then
  echo "Start Docker"
  buildpacks-ci/scripts/start-docker >/dev/null
fi

if [ "$LANGUAGE" = "multi" ]; then
  update_dir="src/compile"
elif [ "$LANGUAGE" = "dotnet-core" ]; then
  update_dir="src/dotnetcore"
else
  update_dir="src/$LANGUAGE"
fi

go get github.com/golang/dep/cmd/dep

pushd buildpack
  source .envrc

  # for the PHP buildpack
  if [ -e run_tests.sh ]; then
    TMPDIR=$(mktemp -d)
    export TMPDIR
    pip install -r requirements.txt
  fi

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
      dep ensure
      dep ensure -update
    fi

    go generate || true
    [ -d compile ] && (cd compile && (go generate || true))
    [ -d hooks ] && (cd hooks && (go generate || true))
    [ -d supply ] && (cd supply && (go generate || true))
    [ -d finalize ] && (cd finalize && (go generate || true))

    export CF_STACK=${CF_STACK:-cflinuxfs2}
    ginkgo -r -skipPackage=integration,brats
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
