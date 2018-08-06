#!/usr/bin/env bash
set -eux
set -o pipefail

source cf-deployment-concourse-tasks/shared-functions

setup_bosh_env_vars
trap "pkill -f ssh" EXIT

bosh -n update-runtime-config bosh-deployment/runtime-configs/dns.yml --name dns
