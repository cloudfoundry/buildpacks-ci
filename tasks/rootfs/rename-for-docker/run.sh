#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

mv stack-s3/${STACK}-*.tar.gz docker-s3/${STACK}.tar.gz
