#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

tar xvf pack-release/release.tgz -o pack # Do not hardcode

cnbs=(nodejs npm yarn) # Do not hardcode
erbCmd="erb "

for i in "${cnbs[@]}"; do
  buildpack="${i}-cnb-release"
  path=$(find "$buildpack" -name "*.tgz")
  erbCmd+="packaged_${i}=$path "
done

erbCmd+="./buildpacks-ci/tasks/update-builder-image/builder-template.toml.erb > final.toml"

if [ "${MASTER}" = "true" ] # Support master release of pack
then

stackConfig=$(cat <<-END
[stack]
id = "org.cloudfoundry.stacks.cflinuxfs3"
build-image = "cfbuildpacks/cflinuxfs3-cnb-experimental:build"
run-image = "cfbuildpacks/cflinuxfs3-cnb-experimental:run"
END
)
  erbCmd+="stack_config=$stackConfig"
  STACK_COMMAND=""

else

  erbCmd+="stack_config='"
  STACK_COMMAND="--stack org.cloudfoundry.stacks.cflinuxfs3"
  ./pack add-stack org.cloudfoundry.stacks.cflinuxfs3 -b cfbuildpacks/cflinuxfs3-cnb-experimental:build -r cfbuildpacks/cflinuxfs3-cnb-experimental:run

fi

eval "$erbCmd"

./buildpacks-ci/scripts/start-docker >/dev/null

img_name="cloudfoundry/cnb"
./pack create-builder "$img_name" --builder-config ./final.toml "${STACK_COMMAND}"
docker save "$img_name" -o ./docker-artifacts/builder.tgz
