#!/bin/bash -l

set -e

cd ci-tools
bundle
scripts/outdated_buildpack_releases
