#!/usr/bin/env bash

set -euo pipefail

generate_diff() {
  version="$(cat version/number)"
  last_released_builder="cloudfoundry/cnb:$TAG"
  release_candidate="gcr.io/cf-buildpacks/builder-rcs:${version}-${TAG}"

  >&2 echo "Generating diff"
  >&2 echo "  Current: $last_released_builder"
  >&2 echo "  RC: $release_candidate"

  tar xf pack/*-linux.tgz -C pack

  gcloud --no-user-output-enabled auth activate-service-account --key-file <(echo "$GCP_SERVICE_ACCOUNT_KEY")
  gcloud --no-user-output-enabled --quiet auth configure-docker

  set +e
  buildpacks_diff="$(diff -u <(get_cnb_names "$last_released_builder") <(get_cnb_names "$release_candidate") | tail -n +3)"
  groups_diff="$(diff -u <(get_detection_order "$last_released_builder") <(get_detection_order "$release_candidate") | tail -n +3)"

  printf -v diff "%s\n%s" "$buildpacks_diff" "$groups_diff"
  if [[ -z $diff ]]; then
    diff="No changes. Nothing to do."
  fi
  set -e

  >&2 echo -e "Diff:\n$diff"
  echo "$diff"
}

get_cnb_names() {
  ./pack/pack --no-color \
    inspect-builder "$1" \
    | sed -n '/^Buildpacks:$/,/^$/p' \
    | sed '1,2d;$d' \
    | sort
}

get_detection_order() {
  ./pack/pack --no-color \
    inspect-builder "$1" \
    | grep -v "ERROR: inspecting local image" \
    | sed -n '/^Detection Order:$/,/^$/p'
}

create_or_get_story() {
  filter="label:$TAG AND label:builder-release AND -state:accepted"
  response="$(curl -s -X GET \
    -H "X-TrackerToken: $TRACKER_API_TOKEN" \
    -H "Accept: application/json" \
    -G --data-urlencode "filter=$filter" \
    "https://www.pivotaltracker.com/services/v5/projects/$TRACKER_PROJECT_ID/stories"
  )"

  if [[ "$response" == '[]' ]]; then
    >&2 echo "Story does not exist"

    response="$(curl -s -X POST \
      -H "X-TrackerToken: $TRACKER_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "{\"name\": \"Release builder $TAG\", \"labels\": [\"$TAG\", \"builder-release\"]}" \
      "https://www.pivotaltracker.com/services/v5/projects/$TRACKER_PROJECT_ID/stories"
    )"

    id="$(echo "$response" | jq -r .id)"

    >&2 echo "Story created with id #$id"
    echo "$id"
  elif [[ "$(echo "$response" | jq -r '. | length')" == 1 ]]; then
    id="$(echo "$response" | jq -r .[0].id)"

    >&2 echo "Story found with id #$id"
    echo "$id"
  else
    >&2 printf "Invalid stories response:\n%s\n" "$response"
    exit 1
  fi
}

update_story() {
  story_id=$1
  description=$2

  >&2 echo "Converting description to JSON-wrapped markdown"

  # shellcheck disable=SC2016
  markdown_description="$(printf '```diff\n%s\n```' "$description")"
  jq -n --arg description "$markdown_description" '{description: $description}' > story-data

  >&2 echo "Updating story description"

  curl -s -X PUT \
    -H "X-TrackerToken: $TRACKER_API_TOKEN" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d @story-data \
    "https://www.pivotaltracker.com/services/v5/projects/$TRACKER_PROJECT_ID/stories/$story_id"
}

main() {
  diff="$(generate_diff)"
  printf "\n"
  story_id="$(create_or_get_story)"
  printf "\n"
  update_story "$story_id" "$diff"
}

main
