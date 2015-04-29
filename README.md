# Introduction

This contains the Concourse CI environment for the Cloud Foundry Buildpacks team.

# Installation

```sh
git clone git@github.com:pivotal-cf/buildpacks-ci
cd buildpacks-ci
```

## Concourse

```sh
vagrant up
```

# Usage

With a proper Concourse deployment, and `private.yml` containing secrets.

```sh
fly c -c pipeline.yml -vf private.yml
```

# Building Docker Images

```sh
docker build -t cfbuildpacks/ci:buildpack .
docker push cfbuildpacks/ci:buildpack
```
