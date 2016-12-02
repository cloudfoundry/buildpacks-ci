# Introduction

This contains the configuration for the Cloud Foundry Buildpacks team [Concourse deployment](https://concourse.buildpacks-gcp.ci.cf-app.com/).

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
* [gems-and-extensions](pipelines/gems-and-extensions.yml): gems and extensions that support buildpack development and deployment
* [notifications](pipelines/notifications.yml): monitor upstream sources for
	changes and notify on Slack
* [stacks](pipelines/stacks.yml): test and release Cloud Foundry [stacks](https://github.com/cloudfoundry/stacks)

# Orphaned branches

The `buildpacks-ci` repository has a number of "orphan branches" used by various jobs and robots to manage state. These branches are:

* [new-release-notifications](https://github.com/cloudfoundry/buildpacks-ci/commits/new-release-notifications) When a dependency included in a buildpack has a new version released, an update is made to this branch

* [binary-builds](https://github.com/cloudfoundry/buildpacks-ci/commits/binary-builds) Used to enqueue build jobs for both manual and automatic builds

* [binary-built-output](https://github.com/cloudfoundry/buildpacks-ci/commits/binary-built-output) When an automatic build finishes, it stores binary signatures and timestamps in this branch.


* [new-cve-notifications](https://github.com/cloudfoundry/buildpacks-ci/commits/new-cve-notifications) Tracks CVEs and sorts them based on whether they affect the rootfs


* [resource-pools](https://github.com/cloudfoundry/buildpacks-ci/commits/resource-pools) Used to control access to the Edge + LTS BOSH-lite environments via the [Concourse Pool Resource](https://github.com/concourse/pool-resource)

* [binary-verification-whitelist](https://github.com/cloudfoundry/buildpacks-ci/commits/binary-verification-whitelist) Every day we verify that binaries being distributed via buildpacks.cloudfoundry.org have the correct checksums. Some binaries are, due to development error, known to be wrong. This branch is a list of files to ignore during verification.

* [new-buildpack-cve-notifications](https://github.com/cloudfoundry/buildpacks-ci/tree/new-cve-notifications) Experimental. Tracks CVEs that affect buildpack dependencies. Currently only implemented for the [ruby-buildpack](https://github.com/cloudfoundry/ruby-buildpack)

# Commands and recipes

## Updating all the Pipelines

```sh
./bin/update-pipelines
```

## Configuration

With a proper Concourse deployment, and `private.yml` containing secrets:

```sh
fly set-pipeline -p main -c pipeline.yml -l private.yml
```

## Debugging the build

```sh
fly intercept -j $JOB_NAME -t task -n $TASK_NAME
```

## Clearing the git resources

```sh
fly intercept -c $RESOURCE_NAME rm -rf /tmp/git-resource-repo-cache
```

## To build a new version of a binary

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
https://concourse.buildpacks-gcp.ci.cf-app.com/pipelines/binary-builder and silently
upload a binary to the `pivotal-buildpacks` bucket under
`dependencies/`,
e.g. https://pivotal-buildpacks.s3.amazonaws.com/dependencies/ruby/ruby-2.2.2-linux-x64.tgz

Note that the array is a stack, which will be emptied as the build
succeeds in packaging successive versions.


## Running the Test Suite

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

# Buildpack Repositories Guide

`buildpacks-ci` pipelines and tasks refer to many other repositories. These repos are where the buildpack team and others develop buildpacks and related artifacts.

## Officially-supported Buildpacks

Each officially-supported buildpack has a `develop` and a `master` branch.

Active development happens on `develop`. Despite our best efforts, `develop` will sometimes be unstable and is not production-ready.

Our release branch is `master`. This is stable and only updated with new buildpack releases.

* [binary-buildpack](https://github.com/cloudfoundry/binary-buildpack)
* [go-buildpack](https://github.com/cloudfoundry/go-buildpack)
* [nodejs-buildpack](https://github.com/cloudfoundry/nodejs-buildpack)
* [php-buildpack](https://github.com/cloudfoundry/php-buildpack)
* [python-buildpack](https://github.com/cloudfoundry/python-buildpack)
* [ruby-buildpack](https://github.com/cloudfoundry/ruby-buildpack)
* [dotnet-core-buildpack](https://github.com/cloudfoundry/dotnet-core-buildpack)
* [staticfile-buildpack](https://github.com/cloudfoundry/static-buildpack)

## Tooling for Development and Runtime

* [buildpack-packager](https://github.com/cloudfoundry/buildpack-packager)   Builds cached and uncached buildpacks
* [machete](https://github.com/cloudfoundry/machete)           Buildpack integration testing framework.
* [compile-extensions](https://github.com/cloudfoundry/compile-extensions) Suite of utility scripts used in buildpacks at runtime
* [binary-builder](https://github.com/cloudfoundry/binary-builder)           Builds binaries against specified rootfs
* [stacks](https://github.com/cloudfoundry/stacks) Tooling to build root file systems ("rootfs") for CF
* [brats](https://github.com/cloudfoundry/brats) Buildpack Runtime Acceptance Test Suite, a collection of smoke tests

## BOSH Releases

BOSH releases are used in the assembly of [`cf-release`](https://github.com/cloudfoundry/cf-release).

* [cflinuxfs2-rootfs-release](https://github.com/cloudfoundry/cflinuxfs2-rootfs-release)
* [go-buildpack-release](https://github.com/cloudfoundry/go-buildpack-release)
* [ruby-buildpack-release](https://github.com/cloudfoundry/ruby-buildpack-release)
* [python-buildpack-release](https://github.com/cloudfoundry/python-buildpack-release)
* [php-buildpack-release](https://github.com/cloudfoundry/php-buildpack-release)
* [nodejs-buildpack-release](https://github.com/cloudfoundry/nodejs-buildpack-release)
* [staticfile-buildpack-release](https://github.com/cloudfoundry/staticfile-buildpack-release)
* [binary-buildpack-release](https://github.com/cloudfoundry/binary-buildpack-release)
* [java-offline-buildpack-release](https://github.com/cloudfoundry/java-offline-buildpack-release)
* [java-buildpack-release](https://github.com/cloudfoundry/java-buildpack-release)

## Experimental or unsupported

### Buildpacks

These buildpacks are possible candidates for promotion, or experimental architecture explorations.

* [multi-buildpack](https://github.com/cloudfoundry-incubator/multi-buildpack)

### Tools

* [concourse-filter](https://github.com/pivotal-cf-experimental/concourse-filter) Redacts credentials from Concourse logs
* [new_version_resource](https://github.com/pivotal-cf-experimental/new_version_resource) Concourse resource to track dependency versions by scraping webpages

## Repos that are retired, deprecated or abandoned

You should not follow or rely on these repos. They may be moved or deleted without warning. They do not contain code under active development.

* [buildpack-releases](https://github.com/cloudfoundry-attic/buildpack-releases), will be progressively replaced by individual buildpack release repos.
* [stacks-release](https://github.com/pivotal-cf-experimental/stacks-release), has been replaced by `cflinuxfs2-rootfs-release`

## Private Repos

Some repositories are private for historical or security reasons. We list them for completeness.

* [deployments-buildpacks](https://github.com/pivotal-cf/deployments-buildpacks) See repository README.
* [buildpacks-ci-robots](https://github.com/pivotal-cf/buildpacks-ci-robots) See repository README.
* [stacks-nc](https://github.com/pivotal-cf/stacks-nc) See repository README.
* [cflinuxfs2-nc-rootfs-release](https://github.com/pivotal-cf/cflinuxfs2-nc-rootfs-release) See repository README.
