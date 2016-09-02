# Introduction

This contains the configuration for the Cloud Foundry Buildpacks team [Concourse deployment](https://buildpacks.ci.cf-app.com/).

# Pipelines

* [binary-builder](pipelines/binary-builder.yml): build binaries for Cloud Foundry buildpacks
* [buildpacks](pipelines/templates/buildpack.yml): test and release all of the buildpacks
* [bosh-lite](pipelines/templates/bosh-lite.yml): deploy CF LTS/Edge environment
* [brats](pipelines/brats.yml): run [BRATS](https://github.com/cloudfoundry/brats) against the master branch of buildpacks
* [buildpack-verification](pipelines/buildpack-verification.yml): generate static site for buildpack verification
* [buildpacks-ci](pipelines/buildpacks-ci.yml): testing tasks for correct usage
* [dockerfile](pipelines/dockerfile.yml): rebuild docker image for buildpack
	pipeline
* [cf-release](pipelines/cf-release.yml): deployment of latest buildpacks to
	cf-release develop
* [main](pipelines/main.yml): tooling
* [notifications](pipelines/notifications.yml): monitor upstream sources for
	changes and notify on Slack
* [stacks](pipelines/stacks.yml): test and release Cloud Foundry [stacks](https://github.com/cloudfoundry/stacks)

# Updating all the Pipelines

```sh
./bin/update-all-the-pipelines
```

# Configuration

With a proper Concourse deployment, and `private.yml` containing secrets:

```sh
fly set-pipeline -p main -c pipeline.yml -l private.yml
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
3. Find the version number and package SHA256 of the new binary. For many binaries, the project website provides the SHA256 along with the release (for example, jruby.org/download provides the SHA256 along with each JRuby release). For others (such as Godep), you download the .tar.gz file and run `shasum -a 256 <tar_file>` to obtain the SHA256.
4. Add any number of versions and their checksums to the array, e.g.

	```yaml
	ruby:
	- version: 2.2.2
	  sha256: 5ffc0f317e429e6b29d4a98ac521c3ce65481bfd22a8cf845fa02a7b113d9b44
	```

5. `git commit -am 'Build ruby 2.2.2' && git push`

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

# Running the Test Suite

If you are running the full test suite, some of the integration tests are dependent on the Lastpass CLI and correctly targeting the fly CLI.

To login to the Lastpass CLI:

```sh
lpass login $USERNAME
```

You will then be prompted for your Lastpass password and Google Authenticator Code.

To login to the Fly CLI and target the buildpacks CI:

```sh
fly -t buildpacks login
```

You will be prompted to select either the Github or Basic Auth authentication methods.

After these are set up, you will be able to run the test suite via:

```sh
rspec
```
