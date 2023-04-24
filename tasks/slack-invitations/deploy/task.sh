#!/bin/bash

set -eu
set -o pipefail

#shellcheck source=../../../util/print.sh
source "${PWD}/ci/util/print.sh"

function main() {
  util::print::title "[task] executing"

  gcloud::authenticate
  gcloud::project::configure
  gcloud::run::deploy
}

function gcloud::authenticate() {
  util::print::info "[task] * authenticating with gcp"

  gcloud auth activate-service-account \
    --key-file <(echo "${SERVICE_ACCOUNT_KEY}")
}

function gcloud::project::configure() {
  util::print::info "[task] * configuring project"

  local project
  project="$(echo "${SERVICE_ACCOUNT_KEY}" | jq -r .project_id)"
  gcloud config set project "${project}"
}

function gcloud::run::deploy() {
  util::print::info "[task] * deploying slack-invitations"

  gcloud run deploy "slack-invitations" \
    --image gcr.io/cf-buildpacks/slack-invitations:latest \
    --max-instances 1 \
    --memory "128Mi" \
    --platform managed \
    --set-env-vars "INVITE_URL=${INVITE_URL}" \
    --allow-unauthenticated \
    --region us-central1
}

main "${@}"
