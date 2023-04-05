#!/usr/bin/env bash
set -euo pipefail

if ! command -v ruby &> /dev/null; then
  echo "[task] Installing ruby..."
  apt update
  apt install -y ruby
fi

echo "[task] Running builder.rb..."
ruby buildpacks-ci/tasks/build-binary-new-cflinuxfs4/build.rb
