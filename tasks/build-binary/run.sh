#!/bin/bash
# buildpacks-ci/tasks/build-binary/run.sh
#
# Thin Concourse task wrapper for the Go binary-builder CLI.
# Compiles the Go binary inside the stack container, then dispatches to it.
set -euo pipefail

GO_VERSION="1.22.5"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
GO_URL="https://go.dev/dl/${GO_TARBALL}"
GO_SHA256="904b924d435eaea086515bc63235b192ea441bd8c9b198c507e85009e6e4c7f0"

# ── Install Go if not present ──────────────────────────────────────────────────
if ! command -v go &>/dev/null || ! go version | grep -q "go${GO_VERSION}"; then
  echo "[task] Installing Go ${GO_VERSION}..."
  apt-get update -qq
  apt-get install -y -qq wget ca-certificates

  wget -q "${GO_URL}" -O "/tmp/${GO_TARBALL}"
  echo "${GO_SHA256}  /tmp/${GO_TARBALL}" | sha256sum -c -
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"
  rm -f "/tmp/${GO_TARBALL}"
fi

export PATH="/usr/local/go/bin:${PATH}"
echo "[task] Using $(go version)"

# ── Compile the binary-builder CLI ────────────────────────────────────────────
echo "[task] Compiling binary-builder..."
go build -o /usr/local/bin/binary-builder ./binary-builder/cmd/binary-builder

# ── Run the build ──────────────────────────────────────────────────────────────
SKIP_COMMIT_FLAG=""
if [ "${SKIP_COMMIT:-false}" = "true" ]; then
  SKIP_COMMIT_FLAG="--skip-commit"
fi

echo "[task] Running binary-builder build --stack ${STACK}..."
binary-builder build \
  --stack "${STACK}" \
  --source-file source/data.json \
  --stacks-dir binary-builder/stacks \
  --php-extensions-dir binary-builder/php_extensions \
  --artifacts-dir artifacts \
  --builds-dir builds-artifacts \
  --dep-metadata-dir dep-metadata \
  ${SKIP_COMMIT_FLAG}
