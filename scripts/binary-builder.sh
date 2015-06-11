#!/bin/bash -l

set -e

apt-get -y install ccache
export PATH=/usr/lib/ccache:$PATH

if [ -f binary-builder-compiler-cache/ccache.tgz ]; then
  tar xzf binary-builder-compiler-cache/ccache.tgz
fi

export CCACHE_DIR=`pwd`/.ccache

pushd binary-builder
gem install bundler --no-ri --no-rdoc
bundle install -j4
bundle exec rspec
popd

tar czf new-ccache.tgz .ccache
