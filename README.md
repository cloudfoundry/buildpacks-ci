# Introduction

This contains the configuration for the Cloud Foundry Buildpacks team [Concourse deployment](https://buildpacks.ci.cf-app.com/).

# Pipelines

* [dependency-builds](pipelines/dependency-builds.yml): build binaries for Cloud Foundry buildpacks
* [buildpacks](pipelines/templates/buildpack.yml): test and release all of the buildpacks
* [edge-shared](pipelines/edge-shared.yml): deploy CF Deployment environment
* [brats](pipelines/brats.yml): run [BRATS](https://github.com/cloudfoundry/brats) against the master branch of buildpacks
* [buildpack-verification](pipelines/buildpack-verification.yml): generate static site for buildpack verification
* [buildpacks-ci](pipelines/buildpacks-ci.yml): testing tasks for correct usage, rebuild CI docker images
* [cf-release](pipelines/cf-release.yml): deployment of latest buildpacks to
	cf-release develop
* [gems-and-extensions](pipelines/gems-and-extensions.yml): gems and extensions that support buildpack development and deployment
* [notifications](pipelines/notifications.yml): monitor upstream sources for
	changes and notify on Slack
* [cflinuxfs2](pipelines/cflinuxfs2.yml): test and release Cloud Foundry [cflinuxfs2](https://github.com/cloudfoundry/cflinuxfs2)

# Concourse State

Jobs and tasks in the `buildpacks-ci` repository store state in [public-buildpacks-ci-robots](https://github.com/cloudfoundry/public-buildpacks-ci-robots). See repository README for details.

# Commands and recipes

## Updating all the Pipelines

```sh
./bin/update-pipelines
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
https://buildpacks.ci.cf-app.com/pipelines/binary-builder and silently
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

## Making Changes to Build Scripts

When you want to change how a binary gets built, there are two places you may need to make changes. All binaries are built by the `dependency-builds` pipeline, and you may need to change the task that builds them. For many binaries, the `dependency-builds` pipeline runs recipes from the `binary-builder` repo; for those binaries, you will usually need to change the recipe rather than the concourse task.

For the list of currently supported binaries, check out our `dependency-builds` [pipeline](https://buildpacks.ci.cf-app.com/teams/main/pipelines/dependency-builds).

The concourse task that orchestrates the building is `buildpacks-ci/tasks/build-binary-new/builder.rb`; many of the recipes are in [binary-builder](https://github.com/cloudfoundry/binary-builder). 

To test these changes locally, you can execute the concourse task for it, but point to local changes. For instance:

```
$ cd buildpacks-ci
$ STACK=cflinuxfs2 fly -t buildpacks e -c tasks/build-binary-new/build.yml -j dependency-builds/build-r-3.4.X -i buildpacks-ci=.
```

For binaries that use recipes in `binary-builder`, you can also test in Docker. For instance:

```
$ docker run -w /binary-builder -v `pwd`:/binary-builder -it cloudfoundry/cflinuxfs2:ruby-2.2.4 ./bin/binary-builder --name=ruby --version=2.2.3 --md5=150a5efc5f5d8a8011f30aa2594a7654
$ ls
ruby-2.2.3-linux-x64.tgz
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
* [libbuildpack](https://github.com/cloudfoundry/libbuildpack) Library used for writing buildpacks in Golang
* [binary-builder](https://github.com/cloudfoundry/binary-builder)           Builds binaries against specified rootfs
* [cflinuxfs2](https://github.com/cloudfoundry/cflinuxfs2) Tooling to build cflinuxfs2 root file system ("rootfs") for CF
* [brats](https://github.com/cloudfoundry/brats) Buildpack Runtime Acceptance Test Suite, a collection of smoke tests

## BOSH Releases

BOSH releases are used in the assembly of [`cf-release`](https://github.com/cloudfoundry/cf-release).

* [cflinuxfs2-release](https://github.com/cloudfoundry/cflinuxfs2-release)
* [go-buildpack-release](https://github.com/cloudfoundry/go-buildpack-release)
* [ruby-buildpack-release](https://github.com/cloudfoundry/ruby-buildpack-release)
* [python-buildpack-release](https://github.com/cloudfoundry/python-buildpack-release)
* [php-buildpack-release](https://github.com/cloudfoundry/php-buildpack-release)
* [nodejs-buildpack-release](https://github.com/cloudfoundry/nodejs-buildpack-release)
* [staticfile-buildpack-release](https://github.com/cloudfoundry/staticfile-buildpack-release)
* [binary-buildpack-release](https://github.com/cloudfoundry/binary-buildpack-release)
* [java-offline-buildpack-release](https://github.com/cloudfoundry/java-offline-buildpack-release)
* [java-buildpack-release](https://github.com/cloudfoundry/java-buildpack-release)
* [dotnet-core-buildpack-release](https://github.com/cloudfoundry/dotnet-core-buildpack-release)

## Experimental or unsupported

### Buildpacks

These buildpacks are possible candidates for promotion, or experimental architecture explorations.

* [hwc-buildpack](https://github.com/cloudfoundry/hwc-buildpack)
* [hwc-buildpack-release](https://github.com/cloudfoundry/hwc-buildpack-release)

### Tools

* [concourse-filter](https://github.com/pivotal-cf-experimental/concourse-filter) Redacts credentials from Concourse logs
* [new_version_resource](https://github.com/pivotal-cf-experimental/new_version_resource) Concourse resource to track dependency versions by scraping webpages

## Private Repos

Some repositories are private for historical or security reasons. We list them for completeness.

* [deployments-buildpacks](https://github.com/pivotal-cf/deployments-buildpacks) See repository README.
* [buildpacks-ci-robots](https://github.com/pivotal-cf/buildpacks-ci-robots) See repository README.
* [cflinuxfs2-nc](https://github.com/pivotal-cf/cflinuxfs2-nc) See repository README.
* [cflinuxfs2-nc-release](https://github.com/pivotal-cf/cflinuxfs2-nc-release) See repository README.

