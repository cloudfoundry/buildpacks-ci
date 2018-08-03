#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source cf-deployment-concourse-tasks/shared-functions

bosh_update_dns_runtime_config
