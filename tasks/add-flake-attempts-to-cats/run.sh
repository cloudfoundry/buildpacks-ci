#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

rsync -vaz cats-concourse-task-inp/ cats-concourse-task/

sed -i s/keepGoing/-flakeAttempts=3/ cats-concourse-task/task
