# Build-binary-stack

## Summary

This directory contains the stack-agnostic task for the
[dependency-builds](https://github.com/cloudfoundry/buildpacks-ci/blob/master/pipelines/dependency-builds/)
pipeline. The code here contains all of the dependency-specific logic that is
needed to compile dependencies for any supported stack (cflinuxfs4, cflinuxfs5, etc.).

## Stack-Agnostic Design

This task is designed to work with any cflinuxfs stack. The stack is passed via:
1. The `STACK` environment variable
2. The Docker image is provided by the pipeline (not hardcoded in build.yml)

This design makes adding new stacks trivial - just add the stack to the pipeline
configuration and the task will work automatically.

## Usage

The dependency-builds pipeline utilizes this code through the [build.yml
file](https://github.com/cloudfoundry/buildpacks-ci/blob/master/tasks/build-binary-stack/build.yml).

The pipeline passes the appropriate Docker image for each stack:
```yaml
image: #@ "{}-image".format(stack)
```

Dependency-specific code lives inside of the [builder.rb
file](https://github.com/cloudfoundry/buildpacks-ci/blob/master/tasks/build-binary-stack/builder.rb).
It functions as a giant switch statement, with a case for each dependency. This
file needs to get updated when a new dependency is added.

In some cases, the compilation code calls out to
[binary-builder](https://github.com/cloudfoundry/binary-builder).

## Other files of interest

This directory contains a number of other files as well:

* PHP extension yamls: each version line of PHP has its own list of related
  extensions that we compile

## Supported Stacks

- cflinuxfs4 (Ubuntu 22.04 Jammy)
- cflinuxfs5 (Ubuntu 24.04 Noble)
