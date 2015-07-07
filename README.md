# Introduction

This contains the Concourse CI environment for the Cloud Foundry Buildpacks team.

# Installation

```sh
git clone git@github.com:pivotal-cf/buildpacks-ci
cd buildpacks-ci
```

# Usage

With a proper Concourse deployment, and `private.yml` containing secrets.

```sh
fly c main -c pipeline.yml -vf private.yml
```

# Building Docker Images

```sh
docker build -t cfbuildpacks/ci:buildpack .
docker push cfbuildpacks/ci:buildpack
```

# Debugging the build

```sh
fly hijack -j $JOB_NAME -t task -n $TASK_NAME
```

# Clearing the git resources

```sh
fly hijack -c $RESOURCE_NAME rm -rf /tmp/git-resource-repo-cache
```

# To build a new version of a binary

1) Check out the `binary-builds` branch
2) Edit the YAML file appropriate for the build (e.g. ruby-builds.yml)
3) Add any number of versions to the array, e.g.
```
ruby:
  - 2.2.2
```
4) git commit -am 'Build ruby 2.2.2' && git push

Build should automatically kick off at https://buildpacks.ci.cf-app.com/pipelines/binary-builder and silently upload a binary to the pivotal-buildpacks bucket under concourse-binaries, e.g. https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/ruby/ruby-2.2.2-linux-x64.tgz

Note that the array is a stack, which will be emptied when the build succeeds.
