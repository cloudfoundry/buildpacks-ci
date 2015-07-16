# Introduction

This contains the configuration for the Cloud Foundry Buildpacks team [Concourse deployment](https://buildpacks.ci.cf-app.com/).

# Pipelines

* [binary-builder](pipelines/binary-builder.yml): build binaries for Cloud Foundry buildpacks
* [binary-buildpack](pipelines/binary-buildpack.yml): test and release the [binary buildpack](https://github.com/cloudfoundry/binary-buildpack)
* [bp-ci-7](pipelines/bp-ci-7.yml): deploy CF LTS to bp-ci-7
* [bp-ci-7b](pipelines/bp-ci-7b.yml): deploy CF LTS to bp-ci-7b
* [bp-ci-8](pipelines/bp-ci-8.yml): deploy CF master to bp-ci-8
* [bp-ci-8b](pipelines/bp-ci-8b.yml): deploy CF master to bp-ci-8b
* [brats-binary-beta](pipelines/brats-binary-beta.yml): run [BRATS](https://github.com/cloudfoundry/brats) against the binary-beta branch of buildpacks
* [brats-develop](pipelines/brats-develop.yml): run [BRATS](https://github.com/cloudfoundry/brats) against the develop branch of buildpacks
* [brats](pipelines/brats.yml): run [BRATS](https://github.com/cloudfoundry/brats) against the master branch of buildpacks
* [go-buildpack](pipelines/go-buildpack.yml): test and release the [Go buildpack](https://github.com/cloudfoundry/go-buildpack)
* [main](pipelines/main.yml): tooling
* [nodejs-buildpack](pipelines/nodejs-buildpack.yml): test and release the [Node.js buildpack](https://github.com/cloudfoundry/nodejs-buildpack)
* [php-buildpack](pipelines/php-buildpack.yml): test and release the [PHP buildpack](https://github.com/cloudfoundry/php-buildpack)
* [python-buildpack](pipelines/python-buildpack.yml): test and release the [Python buildpack](https://github.com/cloudfoundry/python-buildpack)
* [ruby-buildpack](pipelines/ruby-buildpack.yml): test and release the [Ruby buildpack](https://github.com/cloudfoundry/ruby-buildpack)
* [stacks](pipelines/stacks.yml): test and release Cloud Foundry [stacks](https://github.com/cloudfoundry/stacks)
* [staticfile-buildpack](pipelines/staticfile-buildpack.yml): test and release the [staticfile buildpack](https://github.com/cloudfoundry/staticfile-buildpack)

# Configuration

With a proper Concourse deployment, and `private.yml` containing secrets:

```sh
fly c main -c pipeline.yml -vf private.yml
```

# Building Docker Images

```sh
docker build -t cfbuildpacks/ci .
docker push cfbuildpacks/ci
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

1. Check out the `binary-builds` branch
2. Edit the YAML file appropriate for the build (e.g. `ruby-builds.yml`)
3. Add any number of versions to the array, e.g.

	```yaml
	ruby:
	  - 2.2.2
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
