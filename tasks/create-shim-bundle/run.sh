#!/bin/bash -l

set -euo pipefail

version=$(cat version/version)

pushd shim
    GOOS=linux go build -ldflags="-s -w" -o binaries/detect shims/cmd/detect/main.go
    GOOS=linux go build -ldflags="-s -w" -o binaries/supply shims/cmd/supply/main.go
    GOOS=linux go build -ldflags="-s -w" -o binaries/finalize shims/cmd/finalize/main.go
    GOOS=linux go build -ldflags="-s -w" -o binaries/release shims/cmd/release/main.go
popd

pushd binaries
    tar czf ../archive/shim-bundle.tgz detect supply finalize release
popd

sha=$(sha256sum archive/shim-bundle.tgz | cut -d ' ' -f 1)

mv archive/shim-bundle.tgz "archive/shim-bundle-$version-$sha.tgz"