# Build-binary-new

## Summary

This directory is the task needed for the
[dependency-builds](https://github.com/cloudfoundry/buildpacks-ci/blob/master/pipelines/config/dependency-builds.yml)
pipeline. The code here contains all of the dependency-specific logic that is
needed to compile dependencies.

## Usage

The dependency-builds pipeline utilizes this code through the [build.yml
file](https://github.com/cloudfoundry/buildpacks-ci/blob/master/tasks/build-binary-new/build.yml).

Dependency-specific code lives inside of the [builder.rb
file](https://github.com/cloudfoundry/buildpacks-ci/blob/master/tasks/build-binary-new/builder.rb).
It functions as a giant switch statement, with a case for each dependency. This
file needs to get updated when a new dependency is added.

In some of the case, the compilation code calls out to
[binary-builder](https://github.com/cloudfoundry/binary-builder).

## Other files of interest

This directory contains a number of other files as well:

* PHP extension yamls: each version line of PHP has it's own list of related
  extensions that we compile

* create-new-version-line-story: task for creating Tracker stories when new
  version lines are released

* create: task for creating Tracker stories when new patches of already tracked
  versions come out

* accept: task for auto-accepting Tracker stories that get created

