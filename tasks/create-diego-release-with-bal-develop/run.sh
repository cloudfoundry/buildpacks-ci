#!/usr/bin/env bash

set -euo pipefail

export GOROOT="/usr/local/go1.13"
export PATH="$GOROOT/bin:$PATH"

version="0.$(date +%s)"

bal_develop_sha="$(git -C bal-develop rev-parse HEAD)"

pushd diego-release >/dev/null
  git -C src/code.cloudfoundry.org/buildpackapplifecycle fetch
  git -C src/code.cloudfoundry.org/buildpackapplifecycle checkout "$bal_develop_sha"

  export GOPATH="$PWD"
  export PATH="$PWD/bin:$PATH"
  ./scripts/sync-package-specs
  git status
  bosh --parallel 10 sync-blobs
  bosh create-release --force --tarball "dev_releases/diego/diego-$version.tgz" --name diego --version "$version"
popd >/dev/null

cat >diego-release/use-diego-dev-release.yml <<-EOF
---
- path: /releases/name=diego
  type: replace
  value:
    name: diego
    version: $version
EOF
