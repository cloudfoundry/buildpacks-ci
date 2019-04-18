#!/bin/bash -l

set -euo pipefail

version=$(cat version/version)

pushd shim
    GOOS=linux go build -ldflags="-s -w" -o ../detect shims/cmd/detect/main.go
    GOOS=linux go build -ldflags="-s -w" -o ../supply shims/cmd/supply/main.go
    GOOS=linux go build -ldflags="-s -w" -o ../finalize shims/cmd/finalize/main.go
    GOOS=linux go build -ldflags="-s -w" -o ../release shims/cmd/release/main.go
popd

tar czf archive/shim-bundle.tgz detect supply finalize release

sha=$(sha256sum archive/shim-bundle.tgz | cut -d ' ' -f 1)

mv archive/shim-bundle.tgz "archive/shim-bundle-$version-${sha::8}.tgz"