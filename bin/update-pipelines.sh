#!/bin/bash

set -e
set -u
set -o pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
readonly ROOT_DIR

function main() {
  local include
  include=""

  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --help|-h)
        usage
        exit 0
        ;;

      --include|-i)
        include="${2}"
        shift 2
        ;;

      "")
        shift 1
        ;;

      *)
        usage
        util::print::error "unknown argument \"${1}\""
    esac
  done

  team::check
  pipelines::update "${include}"
}

function usage() {
  cat <<-USAGE
update-pipelines.sh [OPTIONS]

OPTIONS
  --help, -h                prints the command usage
  --include, -i <pipeline>  specifies a fragment of a pipeline to match

USAGE
}

function team::check() {
  if ! string::contains "$(yq eval .targets.buildpacks.team ~/.flyrc )" "feature-eng" ; then
    echo "Refusing to update pipelines. Please log in as the 'feature-eng' team using:"
    echo -e "\n  fly -t buildpacks login -n feature-eng\n"
    exit 1
  fi
  return
}

function pipelines::update() {
  local include
  include="${1}"

  local basic_pipelines
  basic_pipelines=(
    ci-images
    interrupt-bot
    slack-invitations
  )

  for name in "${basic_pipelines[@]}"; do
    pipeline::update::basic "${name}" "${include}"
  done
}

function string::contains() {
  local string substring
  string="${1}"
  substring="${2}"

  grep -qi "${substring}" <(echo "${string}")
}

function pipeline::update::basic() {
  local name include
  name="${1}"
  include="${2}"

  if string::contains "${name}" "${include}"; then
    echo "=== UPDATING ${name} ==="
    fly --target buildpacks \
      set-pipeline \
        --pipeline "${name}" \
        --config "${ROOT_DIR}/pipelines/${name}.yml"
    echo
  fi
}

main "$@"
