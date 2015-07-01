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
