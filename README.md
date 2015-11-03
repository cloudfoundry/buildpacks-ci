# Introduction

This contains the configuration for the Cloud Foundry Buildpacks team [Concourse deployment](https://buildpacks.ci.cf-app.com/).

# Pipelines

* [binary-builder](pipelines/binary-builder.yml): build binaries for Cloud Foundry buildpacks
* [buildpacks](pipelines/templates/buildpack.yml): test and release all of the buildpacks
* [bosh-lite](pipelines/templates/bosh-lite.yml): deploy CF LTS/Edge environment
* [brats-develop](pipelines/brats-develop.yml): run [BRATS](https://github.com/cloudfoundry/brats) against the develop branch of buildpacks
* [brats](pipelines/brats.yml): run [BRATS](https://github.com/cloudfoundry/brats) against the master branch of buildpacks
* [buildpack-checksums](pipelines/buildpack-checksums.yml): generate static site for buildpack checksums
* [buildpacks-ci](pipelines/buildpacks-ci.yml): testing tasks for correct usage
* [dockerfile](pipelines/dockerfile.yml): rebuild docker image for buildpack
	pipeline
* [cf-release](pipelines/cf-release.yml): deployment of latest buildpacks to
	cf-release develop
* [main](pipelines/main.yml): tooling
* [notifications](pipelines/notifications.yml): monitor upstream sources for
	changes and notify on Slack
* [stacks](pipelines/stacks.yml): test and release Cloud Foundry [stacks](https://github.com/cloudfoundry/stacks)

# Configuration

With a proper Concourse deployment, and `private.yml` containing secrets:

```sh
fly c main -c pipeline.yml -vf private.yml
```

# Debugging the build

```sh
fly intercept -j $JOB_NAME -t task -n $TASK_NAME
```

# Clearing the git resources

```sh
fly intercept -c $RESOURCE_NAME rm -rf /tmp/git-resource-repo-cache
```

# To build a new version of a binary

1. Check out the `binary-builds` branch
2. Edit the YAML file appropriate for the build (e.g. `ruby-builds.yml`)
3. Add any number of versions and their checksums to the array, e.g.

	```yaml
	ruby:
	- version: 2.2.2
	  sha256: 5ffc0f317e429e6b29d4a98ac521c3ce65481bfd22a8cf845fa02a7b113d9b44
	```

4. `git commit -am 'Build ruby 2.2.2' && git push`

Build should automatically kick off at
https://buildpacks.ci.cf-app.com/pipelines/binary-builder and silently
upload a binary to the pivotal-buildpacks bucket under
concourse-binaries,
e.g. https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/ruby/ruby-2.2.2-linux-x64.tgz

Note that the array is a stack, which will be emptied as the build
succeeds in packaging successive versions.


# Orphaned branches

The `binary-builds` branch is used to instruct the `binary-builder`
pipeline to generate a new version of a CF rootfs-specific binary.

The `resource-pools` branch is where our pipelines' pool of locks is
located. You can read more about Concourse resource pools here:

> https://github.com/concourse/pool-resource
