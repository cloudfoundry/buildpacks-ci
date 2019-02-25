#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail


# build the pack binary from the repo.
# should our builder use urls? or do we add in the buildpack files here?
# save builder-toml file we use to ci-robots
# build a builder image
# get old builder version from dockerhub
# curl 'https://registry.hub.docker.com/v2/repositories/cfbuildpacks/ci/tags/'|jq '."results"[]["name"]'
# push it to dockerhub

pushd nodejs-cnb
    ./scripts/install_tools.sh
    mv .bin/pack ./..
popd

pushd nodejs-cnb
    NODE=$(./scripts/package.sh | grep -e "/tmp/nodejs-cnb_*" | awk -F' ' '{print $4}')
popd

pushd npm-cnb
    NPM=$(./scripts/package.sh | grep -e "/tmp/npm-cnb_*" | awk -F' ' '{print $4}')
popd

pushd yarn-cnb
    YARN=$(./scripts/package.sh | grep -e "/tmp/yarn-cnb_*" | awk -F' ' '{print $4}')
popd

erb packaged_nodejs="$NODE" packaged_npm="$NPM" packaged_yarn="$YARN" ./buildpacks-ci/tasks/update-builder-image/builder-template.toml.erb > final.toml

builder_ver=cflinuxfs3-v"$(cat ./version/cflinuxfs3)"

./pack add-stack org.cloudfoundry.stacks.cflinuxfs3 -b cfbuildpacks/cflinuxfs3-cnb-experimental:build -r cfbuildpacks/cflinuxfs3-cnb-experimental:run
./buildpacks-ci/scripts/start-docker >/dev/null

IMG_NAME="cloudfoundry/cnb:$builder_ver"
./pack create-builder "$IMG_NAME" --builder-config ./final.toml --stack org.cloudfoundry.stacks.cflinuxfs3 #--publish

docker save "$IMG_NAME" -o ./docker-artifacts/builder.tgz
#get docker file we want to push up to
#move output of line 39 to line 40

