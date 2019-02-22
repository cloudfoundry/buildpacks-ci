#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

curl -v "https://environments.toolsmiths.cf-app.com/gcp_engineering_environments/$ENV_ID/renew"
