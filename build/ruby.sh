#! /usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

export GEM_HOME=~/.gem
export GEM_PATH=~/.gem:/usr/local/bundle
export PATH=~/.gem/bin:/usr/local/bundle/bin:$PATH
