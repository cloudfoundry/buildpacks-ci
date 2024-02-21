#!/bin/bash

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
  echo "Ruby is required to run this script"
  exit 1
fi


while getopts ":g:v:" opt; do
  case ${opt} in
    g )
      GEM_TO_TEST=$OPTARG
      ;;
    v )
      RUBY_VERSION_TO_MATCH=$OPTARG
      ;;
    \? )
      echo "Usage: $0 -g <gem_name> -v <ruby_version>"
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument"
      exit 1
      ;;
  esac
done

if [ -z "$GEM_TO_TEST" ] || [ -z "$RUBY_VERSION_TO_MATCH" ]; then
  echo "Both -g <gem_name> and -v <ruby_version> are required"
  exit 1
fi

# Ruby code to be executed
ruby_code=$(cat <<EOF
require 'open-uri'
require 'json'

GEM_TO_TEST           = "$GEM_TO_TEST"
RUBY_VERSION_TO_MATCH = "$RUBY_VERSION_TO_MATCH"

API_URL = "https://rubygems.org/api/v1/versions/#{GEM_TO_TEST}.json"

# Load list of all available versions of GEM_TO_TEST
gem_versions = JSON.parse(open(API_URL).read)

# Process list to find matching Ruby version
matching_gem = gem_versions.find { |gem|
  Gem::Dependency.new('', gem['ruby_version']).
    match?('', RUBY_VERSION_TO_MATCH)
}

puts "Latest version of #{GEM_TO_TEST} " +
     "compatible with Ruby #{RUBY_VERSION_TO_MATCH} " +
     "is #{matching_gem['number']}."
EOF
)

# Execute Ruby code
ruby -e "$ruby_code"
