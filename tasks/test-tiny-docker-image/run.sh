#!/bin/bash -l

set -eux -o pipefail
source /opt/resource/common.sh
sanitize_cgroups
start_docker 3 3 "" ""

wget https://github.com/bats-core/bats-core/archive/master.zip
unzip master.zip
rm -f master.zip
bash bats-core-master/install.sh /usr/local

cd tiny-run-base-dockerfile/tiny/base/run
docker build -t tiny .
bats -t ./tests/test.bats && bats -t ./tests/testapp.bats
