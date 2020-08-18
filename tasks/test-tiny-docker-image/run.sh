#!/bin/bash -l

set -eux -o pipefail
source buildpacks-ci/scripts/start-docker
util::docker::cgroups::sanitize
util::docker::start 3 3 "" ""

wget https://github.com/bats-core/bats-core/archive/master.zip
unzip master.zip
rm -f master.zip
bash bats-core-master/install.sh /usr/local

cd tiny-run-base-dockerfile/tiny/dockerfile/run
docker build -t tiny .
bats -t ./tests/test.bats && bats -t ./tests/testapp.bats
