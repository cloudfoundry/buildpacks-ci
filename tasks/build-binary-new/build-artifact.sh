#!/usr/bin/env bash

# ********* DETAILS *********
# This script can be used to build buildpack dependencies locally
# Pass in the name of the dependency, the version to build, and the directory to put the artifact
# Dependency names come from binary-builder-new.yml
# This script assumes a specific directory structure as these repos are needed:
# $HOME/workspace/buildpacks-ci
# $HOME/workspace/binary-builder
# $HOME/workspace/public-buildpacks-ci-robots
#
# These directories can also be passed in as args

set -eo pipefail

dep_name=$1
version=$2
artifacts=$3
buildpacks_ci=$4
binary_builder=$5

if [[ -z "$dep_name" || -z "$version" || -z "$artifacts" ]]; then
  echo "Usage: $0 <Dependency Name> <Version> <Artifact Output Dir> <Optional: buildpacks-ci Dir> <Optional: binary-builder Dir>"
  exit 1
fi

if [[ -z "$buildpacks_ci" ]]; then
  buildpacks_ci="$HOME/workspace/buildpacks-ci"
fi

if [[ -z "$binary_builder" ]]; then
  binary_builder="$HOME/workspace/binary-builder"
fi

export STACK=${STACK:-cflinuxfs3}
source_type=$(echo "$(erb -x pipelines/binary-builder-new.yml);puts dependencies['$dep_name'].fetch(:source_type, '$dep_name')" | ruby)

data=$(cat <<-EOF
{
  \"source\": {
    \"type\": \"$source_type\",
    \"name\": \"$dep_name\"
  },
  \"version\": {
    \"ref\": \"$version\"
  }
}
EOF
)

command=$(cat <<-EOF
curl -sL "https://keybase.io/crystal/pgp_keys.asc" | apt-key add -
echo "deb https://dist.crystal-lang.org/apt crystal main" | tee /etc/apt/sources.list.d/crystal.list
apt-get update
apt-get install crystal -y

mkdir /tmp/source

crystal build buildpacks-ci/dockerfiles/depwatcher/src/in.cr -o /tmp/in
echo "$data" | /tmp/in /tmp/source

buildpacks-ci/tasks/build-binary-new/build.rb

EOF
)

docker run -e "STACK=$STACK" -e "SKIP_COMMIT=true" -v "$buildpacks_ci":/tmp/buildpacks-ci -v "$binary_builder":/tmp/binary-builder -v "$artifacts":/tmp/artifacts -w/tmp -it "cloudfoundry/$STACK" "bash" "-cl" "$command"
