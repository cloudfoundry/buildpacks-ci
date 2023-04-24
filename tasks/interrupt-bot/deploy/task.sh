#!/bin/bash

set -eu
set -o pipefail

#shellcheck source=../../../util/print.sh
source "${PWD}/ci/util/print.sh"

function main() {
  util::print::title "[task] executing"

  gcloud::authenticate
  gcloud::run::deploy
}

function gcloud::authenticate() {
  util::print::info "[task] * authenticating with gcp"

  gcloud auth activate-service-account \
    --key-file <(echo "${SERVICE_ACCOUNT_KEY}")
}

function gcloud::run::deploy() {
  util::print::info "[task] * deploying interrupt-bot"

  local project
  project="$(echo "${SERVICE_ACCOUNT_KEY}" | jq -r .project_id)"

  gcloud run deploy interrupt-bot \
    --image gcr.io/cf-buildpacks/slack-delegate-bot:latest \
    --max-instances 1 \
    --memory "128Mi" \
    --platform managed \
    --set-env-vars "SLACK_TOKEN=${SLACK_TOKEN},PAIRIST_PASSWORD=${PAIRIST_PASSWORD}" \
    --allow-unauthenticated \
    --project "${project}" \
    --region us-central1
}

main "${@}"
