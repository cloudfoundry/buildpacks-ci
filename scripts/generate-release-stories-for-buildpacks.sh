#!/bin/bash
fly -t buildpacks login -c https://buildpacks.ci.cf-app.com

timeout=300
sleep_time=30

bps="$(fly -t buildpacks pipelines | grep "\-buildpack" | awk '{print $1;}')";

for bp in $bps; do
  previous_job_number=$(fly -t buildpacks jobs -p $bp --json | jq -c '.[] | select( .name == "create-buildpack-release-story" ) | .finished_build | .name')
  fly -t buildpacks tj -j "$bp/create-buildpack-release-story"

  current_job_number=$(fly -t buildpacks jobs -p $bp --json | jq -c '.[] | select( .name == "create-buildpack-release-story" ) | .next_build | .name')

  if [[ $current_job_number != $previous_job_number ]]
  then
    while [[ $timeout -gt 0 ]]; do
      sleep $sleep_time
      let "timeout=$timeout-$sleep_time"
      next_build=$(fly -t buildpacks jobs -p $bp --json | jq -c '.[] | select( .name == "create-buildpack-release-story" ) | .next_build')
      if [[ $next_build == "null" ]]; then
        echo "$bp/create-buildpack-release-story status is: $(fly -t buildpacks jobs -p $bp --json | jq -r '.[] | select( .name == "create-buildpack-release-story" ) | .finished_build | .status')"
        break
      fi
    done
    fi


  done
