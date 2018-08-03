#!/usr/bin/env bash
set -eux
set -o pipefail

# this repo expects bosh2 to be bosh
ln -s /usr/local/bin/bosh2 /usr/local/bin/bosh
source cf-deployment-concourse-tasks/shared-functions

setup_bosh_env_vars
bosh_update_dns_runtime_config
