#!/bin/bash

set -eu
set -o pipefail

function main(){
    local env_name

    if [[ -z "${ENV_NAME}" ]]; then
        env_name=$(curl -s -XPOST "https://environments.toolsmiths.cf-app.com/pooled_gcp_engineering_environments/claim?api_token=${TOOLSMITHS_API_TOKEN}&pool_name=cf-deployment" | jq -r .name)
    else
        env_name="${ENV_NAME}"
    fi

    curl -s -XGET \
        "https://environments.toolsmiths.cf-app.com/pooled_gcp_engineering_environments/claim?api_token=${TOOLSMITHS_API_TOKEN}&environment_name=$env_name" \
        > "metadata/$env_name.json"

    echo "${env_name}" > metadata/name
}

main
