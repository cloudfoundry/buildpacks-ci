#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -x

echo "Before sourcing..."
source cf-deployment-concourse-tasks/shared-functions
echo "After sourcing..."
bosh_update_dns_runtime_config
echo "After config update..."
