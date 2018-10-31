#!/usr/bin/env bash

set -o pipefail
set -o nounset

set +x
cf_password=$(grep "cf_admin_password:" "bbl-state/$ENV_NAME/vars-store.yml" | awk '{print $2}')
target="api.$ENV_NAME.buildpacks-gcp.ci.cf-app.com"
cf api "$target" --skip-ssl-validation || (sleep 4 && cf api "$target" --skip-ssl-validation)

if [ "$?" == "1" ]; then #This is run before deploying the environment so this can fail
  exit 0
fi

cf auth admin "$cf_password" || (sleep 4 && cf auth admin "$cf_password")
set -x

custom_buildpacks=$(cf buildpacks | tail -n +4 | cut -d ' ' -f1 | grep -v 'hwc_buildpack\|apt_buildpack\|binary_buildpack\|credhub_buildpack\|dotnet_core_buildpack\|go_buildpack\|nginx_buildpack\|nodejs_buildpack\|php_buildpack\|python_buildpack\|r_buildpack\|ruby_buildpack\|staticfile_buildpack\|java_buildpack' || true)
null_buildpacks=$(cf buildpacks | tail -n +4 | grep -v 'cflinuxfs2\|cflinuxfs3\|windows2012R2\|windows2016' | cut -d ' ' -f1 || true)

for bp in $custom_buildpacks $null_buildpacks; do
  cf delete-buildpack "$bp" -f
done

for windows_stack in windows2012R2 windows2016; do
  hwc_buildpacks=$(cf buildpacks | tail -n +4 | grep "hwc_buildpack" | grep $windows_stack) || true

  if [[ "$hwc_buildpacks" == "" ]]; then
    pushd hwc-buildpack
      export GOPATH="$PWD"
      export GOBIN=$PWD/.bin
      export PATH=$GOBIN:$PATH
      git submodule update --init --recursive
      (cd src/*/vendor/github.com/cloudfoundry/libbuildpack/packager/buildpack-packager && go install)

      buildpack-packager build -stack "$windows_stack"
      cf create-buildpack hwc_buildpack hwc_buildpack-*.zip 999
      rm hwc_buildpack-*.zip
    popd
  fi
done

