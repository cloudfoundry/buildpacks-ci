#!/usr/bin/env bash

set -euo pipefail

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Docker is required to run this script"
  exit 1
fi

while getopts ":r:v:g:" opt; do
  case ${opt} in
    r )
      repo=$OPTARG
      ;;
    v )
      version=$OPTARG
      ;;
    g )
      github_token=$OPTARG
      ;;
    \? )
      echo "Usage: $0 -r <Stack repo in the format org/repo> -v <version of the stack, eg 1.75.0> -g <GitHub token>"
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument"
      exit 1
      ;;
  esac
done

if [ -z "$repo" ] || [ -z "$version" ] || [ -z "$github_token" ]; then
  echo "All -r <Stack repo in the format org/repo> -v <version of the stack, eg 1.75.0> -g <GitHub token> are required"
  exit 1
fi

stack=$(echo "$repo" | cut -d'/' -f2 | sed 's/tanzu-//')

# Run the script in a Docker container using the cfbuildpacks/ci image
docker run --rm -v "$(pwd)":/usr/src/app -w /usr/src/app cfbuildpacks/ci bash -c "bundle exec ruby ./scripts/generate-release-notes-cf-stacks.rb '$repo' '$version' '$github_token' '$stack'"

cat release-notes
rm release-notes