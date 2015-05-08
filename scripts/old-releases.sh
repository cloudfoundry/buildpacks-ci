#!/bin/bash -l

pushd ci-tools
  bundle
  scripts/outdated_buildpack_releases
popd
