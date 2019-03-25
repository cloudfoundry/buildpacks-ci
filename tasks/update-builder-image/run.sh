#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

tar xvf pack-release/release.tgz -o pack # Do not hardcode

cnbs=(nodejs npm yarn) # Do not hardcode
erbCmd="erb "

for i in "${cnbs[@]}"; do
  buildpack="${i}-cnb"
  pushd "$buildpack"
    path=$(./scripts/package.sh | grep -e "packaged into" | awk -F' ' '{print $4}')
  popd
  erbCmd+="packaged_${i}=$path "
done

erbCmd+="./buildpacks-ci/tasks/update-builder-image/builder-template.toml.erb > final.toml"
eval "$erbCmd"

./pack add-stack org.cloudfoundry.stacks.cflinuxfs3 -b cfbuildpacks/cflinuxfs3-cnb-experimental:build -r cfbuildpacks/cflinuxfs3-cnb-experimental:run
./buildpacks-ci/scripts/start-docker >/dev/null

img_name="cloudfoundry/cnb"
./pack create-builder "$img_name" --builder-config ./final.toml --stack org.cloudfoundry.stacks.cflinuxfs3
docker save "$img_name" -o ./docker-artifacts/builder.tgz
