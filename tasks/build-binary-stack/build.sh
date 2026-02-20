#!/usr/bin/env bash
set -euo pipefail

RUBY_VERSION="3.4.6"

if ! command -v ruby &> /dev/null || ! ruby --version | grep -q "3.4"; then
  echo "[task] Installing ruby ${RUBY_VERSION}..."
  apt update
  apt install -y wget build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev libffi-dev
  
  pushd /tmp
  wget -q https://cache.ruby-lang.org/pub/ruby/3.4/ruby-${RUBY_VERSION}.tar.gz
  tar -xzf ruby-${RUBY_VERSION}.tar.gz
  cd ruby-${RUBY_VERSION}
  ./configure --disable-install-doc
  make -j$(nproc)
  make install
  popd
  rm -rf /tmp/ruby-${RUBY_VERSION}*
fi

echo "[task] Running builder.rb for stack: ${STACK}..."
ruby buildpacks-ci/tasks/build-binary-stack/build.rb
