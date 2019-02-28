#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

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

./pack add-stack org.cloudfoundry.stacks.cflinuxfs3 -b cfbuildpacks/cflinuxfs3-cnb-experimental:build -r cfbuildpacks/cflinuxfs3-cnb-experimental:run
./buildpacks-ci/scripts/start-docker >/dev/null

IMG_NAME="cloudfoundry/cnb"
./pack create-builder "$IMG_NAME" --builder-config ./final.toml --stack org.cloudfoundry.stacks.cflinuxfs3

docker save "$IMG_NAME" -o ./docker-artifacts/builder.tgz

