#!/bin/bash -l

set -ex

# apt-get -y install ccache
# export PATH=/usr/lib/ccache:$PATH

# if [ -f binary-builder-compiler-cache/ccache.tgz ]; then
#   tar xzf binary-builder-compiler-cache/ccache.tgz
# fi

# export CCACHE_DIR=`pwd`/.ccache

pushd binary-builder

ls spec/**/*_spec.rb | split -l $(expr `ls spec/**/*_spec.rb | wc -l` / $TOTAL_GROUPS)
specs=$(cat $(ls x* | sed -n "$CURRENT_GROUP p"))

gem install bundler --no-ri --no-rdoc
bundle install -j4
bundle exec rspec $specs
popd

tar czf ccache.tgz .ccache
