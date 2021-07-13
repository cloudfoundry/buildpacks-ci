#!/bin/bash
fly -t buildpacks login -c https://buildpacks.ci.cf-app.com

bps="$(fly -t buildpacks pipelines | grep "\-buildpack" | awk '{print $1;}')";

for bp in $bps; do
  fly -t buildpacks tj -j $bp"/create-buildpack-release-story"
done