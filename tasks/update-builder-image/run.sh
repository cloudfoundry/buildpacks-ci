#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

tar xvf pack-release/release.tgz -o pack # Do not hardcode

cnbs=(nodejs npm yarn) # Do not hardcode
erbCmd="erb "

for i in "${cnbs[@]}"; do
  buildpack="${i}-cnb-release"
  pushd "$buildpack"
    path=$(./scripts/package.sh | grep -e "packaged into" | awk -F' ' '{print $4}')
  popd
  erbCmd+="packaged_${i}=$path "
done

erbCmd+="./buildpacks-ci/tasks/update-builder-image/builder-template.toml.erb > final.toml"
eval "$erbCmd"

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
  STACK_COMMAND=" --stack org.cloudfoundry.stacks.cflinuxfs3"
  ./pack add-stack org.cloudfoundry.stacks.cflinuxfs3 -b cfbuildpacks/cflinuxfs3-cnb-experimental:build -r cfbuildpacks/cflinuxfs3-cnb-experimental:run

fi

./buildpacks-ci/scripts/start-docker >/dev/null

img_name="cloudfoundry/cnb"
./pack create-builder "$img_name" --builder-config ./final.toml --stack org.cloudfoundry.stacks.cflinuxfs3 "${STACK_COMMAND}"
docker save "$img_name" -o ./docker-artifacts/builder.tgz
