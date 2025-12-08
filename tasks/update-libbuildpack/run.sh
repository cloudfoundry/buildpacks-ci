#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

if [ "$LANGUAGE" = "dotnet-core" ]; then
  update_dir="src/dotnetcore"
else
  update_dir="src/$LANGUAGE"
fi

pushd buildpack
  source .envrc

  go get -u github.com/cloudfoundry/libbuildpack
  go get github.com/golang/mock/gomock
  go install github.com/onsi/ginkgo/ginkgo@latest
  pushd /tmp
    go install github.com/golang/mock/mockgen@latest
  popd
  go mod tidy
  if [[ "$SHIM" == "true" ]]; then
    go mod vendor
  fi

  if [[ -d "$update_dir" ]]; then
    pushd "$update_dir"

      go generate || true
      [ -d compile ] && (cd compile && (go generate || true))
      [ -d hooks ] && (cd hooks && (go generate || true))
      [ -d supply ] && (cd supply && (go generate || true))
      [ -d finalize ] && (cd finalize && (go generate || true))

      export CF_STACK=${CF_STACK:-cflinuxfs3}
      if [[ "$SHIM" == "true" ]]; then
            ginkgo -r -mod=vendor -skipPackage=integration,brats
      else
            ginkgo -r -skipPackage=integration,brats
      fi
    popd
  fi

  git add .

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
