#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
set -x

export BUILDDIR=$PWD
cd buildpacks-site/downloader
bundle
bundle exec dl.rb "${BUILDDIR}/buildpacks-json/buildpacks.json"
