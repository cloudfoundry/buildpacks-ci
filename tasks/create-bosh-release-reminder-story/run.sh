#!/usr/bin/env bash

set -euo pipefail

content=$(cat << EOF
{
  "before_id": $TRACKER_RELEASE_REMINDER_MARKER_STORY,
  "estimate": 0,
  "name": "**Release:** Buildpack BOSH Releases",
  "description": "Publish buildpack BOSH releases for OSS CF and for TAS.\n\nSee [release runbook](https://github.com/pivotal-cf/tanzu-buildpacks/wiki/Releasing-CF-Buildpacks) for details.",
  "tasks": [
    { "description": "Publish OSS BOSH releases" },
    { "description": "Publish offline (TAS) BOSH releases" }
  ],
  "labels": ["release", "bosh"]
}
EOF
)

response=$(curl -s \
    -X POST \
    -H "X-TrackerToken: $TRACKER_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$content" \
    "https://www.pivotaltracker.com/services/v5/projects/$TRACKER_PROJECT_ID/stories")

echo "$response"

if [[ "$response" == *'"error":'* ]]; then
    echo "Error creating story"
    exit 1
else
  echo "Story created successfully"
fi
