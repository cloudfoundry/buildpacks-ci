# cflinuxfs5 Stack Implementation Guide

## Overview

This document provides a comprehensive guide for adding cflinuxfs5 stack support to the buildpacks-ci repository alongside the existing cflinuxfs4 stack. cflinuxfs5 will be based on Ubuntu 24.04 LTS (Noble Numbat).

**Key Design Decision:** This implementation uses a **stack-agnostic approach** for task files, eliminating the need for duplicate task directories per stack. This makes adding future stacks trivial and reduces maintenance burden.

## Prerequisites

Before implementing cflinuxfs5 support in buildpacks-ci, ensure the following repositories exist and are properly configured:

1. **cflinuxfs5** - The rootfs repository (https://github.com/cloudfoundry/cflinuxfs5)
2. **cflinuxfs5-release** - The BOSH release for cflinuxfs5 (https://github.com/cloudfoundry/cflinuxfs5-release)
3. **Docker image** - `cloudfoundry/cflinuxfs5` on Docker Hub

## Implementation Phases

### Phase 1: Refactor Tasks to be Stack-Agnostic (Prerequisite Refactoring)

Before adding cflinuxfs5, refactor the existing stack-specific tasks to be stack-agnostic. This is a one-time effort that will make adding cflinuxfs5 (and future stacks) trivial.

#### 1.1 Current State Analysis

The current `tasks/build-binary-new-cflinuxfs4/` directory has these stack-specific references:

| File | Line | Current Value | Issue |
|------|------|---------------|-------|
| `build.yml` | 6 | `repository: cloudfoundry/cflinuxfs4` | Hardcoded stack |
| `build.yml` | 28 | `path: buildpacks-ci/tasks/build-binary-new-cflinuxfs4/build.sh` | Hardcoded path |
| `build.sh` | 23 | `ruby buildpacks-ci/tasks/build-binary-new-cflinuxfs4/build.rb` | Hardcoded path |
| `builder.rb` | 143 | `cflinuxfs4` in Ruby download URL | Hardcoded stack |
| `builder.rb` | 148 | `Dir.chdir('binary-builder/cflinuxfs4')` | Hardcoded stack |
| `binary_builder_wrapper.rb` | 4 | `base_dir = File.join('binary-builder', 'cflinuxfs4')` | Hardcoded stack |

#### 1.2 Create Stack-Agnostic Build Binary Task

**Step 1: Create new directory structure**

```bash
mkdir -p tasks/build-binary-new
```

**Step 2: Create `tasks/build-binary-new/build.yml`**

The Docker image will be passed from the pipeline, not hardcoded:

```yaml
---
platform: linux
# NOTE: image_resource is NOT defined here - it's passed from the pipeline
# The pipeline uses: image: #@ "{}-image".format(stack)
inputs:
  - name: binary-builder
  - name: buildpacks-ci
  - name: source
  - name: builds
    optional: true
  - name: source-forecast-latest
    optional: true
  - name: source-rserve-latest
    optional: true
  - name: source-plumber-latest
    optional: true
  - name: source-shiny-latest
    optional: true
outputs:
  - name: artifacts
  - name: builds-artifacts
  - name: dep-metadata
run:
  path: buildpacks-ci/tasks/build-binary-new/build.sh
params:
  STACK:
  SKIP_COMMIT:
```

**Step 3: Create `tasks/build-binary-new/build.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

RUBY_VERSION="3.4.6"

if ! command -v ruby &> /dev/null || ! ruby --version | grep -q "3.4"; then
  echo "[task] Installing ruby ${RUBY_VERSION}..."
  apt update
  apt install -y wget build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev libffi-dev
  
  pushd /tmp
  wget -q https://cache.ruby-lang.org/pub/ruby/3.4/ruby-${RUBY_VERSION}.tar.gz
  tar -xzf ruby-${RUBY_VERSION}.tar.gz
  cd ruby-${RUBY_VERSION}
  ./configure --disable-install-doc
  make -j$(nproc)
  make install
  popd
  rm -rf /tmp/ruby-${RUBY_VERSION}*
fi

echo "[task] Running builder.rb for stack: ${STACK}..."
ruby buildpacks-ci/tasks/build-binary-new/build.rb
```

**Step 4: Create `tasks/build-binary-new/build.rb`**

```ruby
#!/usr/bin/env ruby
require_relative 'builder'
require_relative 'binary_builder_wrapper'
require_relative 'source_input'
require_relative 'build_input'
require_relative 'build_output'
require_relative 'artifact_output'
require_relative 'dep_metadata_output'

include Runner
include Sha
include Archive
include HTTPHelper

def main
  stack           = ENV.fetch('STACK')
  binary_builder  = BinaryBuilderWrapper.new(Runner, stack)
  source_input    = SourceInput.from_file('source/data.json')
  skip_commit     = ENV['SKIP_COMMIT'] == 'true'
  build_input     = skip_commit ? BuildInput.new(nil, nil) : BuildInput.from_file('source/data.json')
  build_output    = BuildOutput.new(source_input.name)
  artifact_output = ArtifactOutput.new(File.join(Dir.pwd, 'artifacts'))
  dep_metadata_output = DepMetadataOutput.new(File.join(Dir.pwd, 'dep-metadata'))
  out_data = Builder.new.execute(
    binary_builder,
    stack,
    source_input,
    build_input,
    build_output,
    artifact_output,
    dep_metadata_output,
    "#{__dir__}/php_extensions",
    skip_commit
  )
  p out_data
end

main
```

**Step 5: Create `tasks/build-binary-new/binary_builder_wrapper.rb`**

```ruby
class BinaryBuilderWrapper
  attr_reader :base_dir

  def initialize(runner, stack)
    @runner = runner
    @stack = stack
    @base_dir = File.join('binary-builder', stack)
  end

  def build(source_input, extension_file = nil)
    digest_arg = if source_input.md5?
                   "--md5=#{source_input.md5}"
                 else
                   "--sha256=#{source_input.sha256}"
                 end

    version_prefix = %w[dep glide godep].include?(source_input.name) ? 'v' : ''

    Dir.chdir(@base_dir) do
      if extension_file && extension_file != ''
        @runner.run('./bin/binary-builder', "--name=#{source_input.name}", "--version=#{version_prefix}#{source_input.version}", digest_arg, extension_file)
      else
        @runner.run('./bin/binary-builder', "--name=#{source_input.name}", "--version=#{version_prefix}#{source_input.version}", digest_arg)
      end
    end
  end
end
```

**Step 6: Update `tasks/build-binary-new/builder.rb`**

Update the `DependencyBuildHelper.setup_ruby` method to be stack-agnostic:

```ruby
module DependencyBuildHelper
  class << self
    def setup_ruby
      stack = ENV.fetch('STACK')
      puts "Updating ruby for stack: #{stack}"
      Runner.run('mkdir', '-p', '/opt/ruby')
      
      # Use stack-appropriate Ruby binary
      ruby_url = "https://buildpacks.cloudfoundry.org/dependencies/ruby/ruby_3.3.6_linux_x64_#{stack}_e4311262.tgz"
      Runner.run('curl', '-L', '-o', '/opt/ruby/ruby3.3.6.tgz', ruby_url)
      Runner.run('tar', '-xzf', '/opt/ruby/ruby3.3.6.tgz', '-C', '/opt/ruby')
      ENV['PATH'] = "/opt/ruby/bin:#{ENV.fetch('PATH', nil)}"
      Runner.run('ruby', '--version')
      
      # Update Gemfile in the stack-specific binary-builder directory
      Dir.chdir("binary-builder/#{stack}") do
        Runner.run('sed', '-i', "s/^ruby .*/ruby '3.3.6'/", 'Gemfile')
        puts('[DEBUG] running bundle install')
        Runner.run('bundle', 'install')
        puts('[DEBUG] finished bundle install')
      end
    end
    
    # ... rest of the module remains the same
  end
end
```

**Step 7: Copy remaining files**

Copy these files unchanged from `tasks/build-binary-new-cflinuxfs4/`:
- `source_input.rb`
- `build_input.rb`
- `build_output.rb`
- `artifact_output.rb`
- `dep_metadata_output.rb`
- `php_extensions/` (entire directory)
- `README.md`

#### 1.3 Create Stack-Agnostic CVE Check Task

**Step 1: Create new directory**

```bash
mkdir -p tasks/check-for-new-rootfs-cves
```

**Step 2: Create `tasks/check-for-new-rootfs-cves/task.yml`**

```yaml
---
platform: linux
image_resource:
  type: docker-image
  source:
    repository: cfbuildpacks/ci
    username: ((cfbuildpacks-dockerhub-user.username))
    password: ((cfbuildpacks-dockerhub-user.password))
inputs:
  - name: new-cves
  - name: buildpacks-ci
  - name: rootfs
outputs:
  - name: output-new-cves
params:
  STACK:
  UBUNTU_VERSION:
  UBUNTU_CODENAME:
run:
  path: bash
  args:
    - -c
    - |
      set -e
      rsync -a new-cves/ output-new-cves
      cd buildpacks-ci && bundle exec ruby ./tasks/check-for-new-rootfs-cves/run.rb
```

**Step 3: Create `tasks/check-for-new-rootfs-cves/run.rb`**

```ruby
#!/usr/bin/env ruby

# Stack-agnostic CVE checker
# Required environment variables:
#   STACK - e.g., 'cflinuxfs4', 'cflinuxfs5'
#   UBUNTU_VERSION - e.g., 'Ubuntu 22.04', 'Ubuntu 24.04'
#   UBUNTU_CODENAME - e.g., 'ubuntu22.04', 'ubuntu24.04'

stack = ENV.fetch('STACK')
ubuntu_version = ENV.fetch('UBUNTU_VERSION')
ubuntu_codename = ENV.fetch('UBUNTU_CODENAME')

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
stacks_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'rootfs'))
cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'output-new-cves', 'new-cve-notifications'))

require "#{buildpacks_ci_dir}/lib/rootfs-cve-notifier"

cve_notifier = RootFSCVENotifier.new(cves_dir, stacks_dir)
cve_notifier.run!(stack, ubuntu_version, ubuntu_codename, [])
```

#### 1.4 Update Dependency Builds Pipeline

**File:** `pipelines/dependency-builds/pipeline.yml`

Update the task file reference to use the stack-agnostic task (around line 331):

```yaml
#@ for stack in build_stacks:
- do:
  - task: #@ "build-binary-{}".format(stack)
    image: #@ "{}-image".format("cflinuxfs4" if stack == "any-stack" else stack)
    file: buildpacks-ci/tasks/build-binary-new/build.yml
    output_mapping:
      artifacts: #@ "{}-artifacts".format(stack)
      builds-artifacts: #@ "{}-builds-metadata".format(stack)
    params:
      STACK: #@ stack
#@ end
```

#### 1.5 Deprecate Old Task Directories

After the stack-agnostic tasks are working:

1. Mark `tasks/build-binary-new-cflinuxfs4/` as deprecated
2. Mark `tasks/check-for-new-rootfs-cves-cflinuxfs4/` as deprecated
3. Remove them in a future cleanup PR

### Phase 2: Core Configuration Updates

#### 2.1 Dependency Builds Configuration

**File:** `pipelines/dependency-builds/config.yml`

Add cflinuxfs5 to the build configuration:

```yaml
# Add to the end of the file, after cflinuxfs4 entries:

cflinuxfs5_build_dependencies: [ 'libunwind', 'libgdiplus', 'node', 'pip', 'pipenv', 'python', 'go', 'godep', 'glide', 'dep', 'ruby', 'jruby', 'nginx', 'nginx-static', 'openresty', 'r' , 'httpd', 'php', 'jprofiler-profiler', 'your-kit-profiler', 'openjdk', 'zulu', 'sapmachine' ]

cflinuxfs5_dependencies: [ 'bower', 'libunwind', 'libgdiplus', 'node', 'dotnet-sdk', 'dotnet-runtime', 'dotnet-aspnetcore', 'pipenv', 'python', 'yarn', 'setuptools', 'miniconda3-py39', 'go', 'godep', 'glide', 'dep', 'ruby', 'jruby', 'bundler', 'rubygems', 'nginx', 'nginx-static', 'openresty', 'r', 'appdynamics', 'composer', 'httpd', 'php', 'tomcat', 'skywalking-agent', 'jprofiler-profiler', 'your-kit-profiler', 'openjdk', 'zulu', 'sapmachine', 'appdynamics-java' ]

cflinuxfs5_buildpacks: [ 'dotnet-core' , 'nodejs', 'python', 'go', 'ruby', 'nginx', 'r', 'php', 'staticfile', 'java' ]

# Update build_stacks to include cflinuxfs5:
build_stacks: [ 'cflinuxfs4', 'cflinuxfs5' ]
```

**Note:** Some dependencies may need `skip_lines_cflinuxfs5` entries if certain version lines are incompatible with Ubuntu 24.04 (e.g., older Ruby versions incompatible with OpenSSL 3.x).

#### 2.2 Dependency Builds Pipeline

**File:** `pipelines/dependency-builds/pipeline.yml`

The pipeline uses YTT templating and iterates over `data.values.build_stacks`. Adding cflinuxfs5 to `build_stacks` in config.yml will automatically:
- Create `cflinuxfs5-image` resource
- Generate build jobs for cflinuxfs5 stack

Add skip lines handling for cflinuxfs5:

```yaml
# Around line 224, add:
#@   skipped_version_lines_fs5 = getattr(dep, "skip_lines_cflinuxfs5", [])

# Around line 302-304, add similar logic for cflinuxfs5:
#@     if line.lower() in [sl.lower() for sl in skipped_version_lines_fs5]:
#@       build_stacks = [s for s in build_stacks if s != "cflinuxfs5"]
#@     end
```

### Phase 3: Rootfs Pipeline

#### 3.1 Create cflinuxfs5 Pipeline

**File:** `pipelines/cflinuxfs5.yml`

Create a new pipeline based on `cflinuxfs4.yml`. Key changes:

1. Replace all `cflinuxfs4` references with `cflinuxfs5`
2. Update Ubuntu version references (22.04 -> 24.04)
3. Update stemcell to use Ubuntu Noble (when available)
4. Update CVE notification paths
5. **Use the stack-agnostic CVE task**

```yaml
#@ buildpacks = ["binary", "dotnet-core", "go", "java", "nodejs", "php", "python", "ruby", "staticfile"]

---
resource_types:
- name: cron
  type: docker-image
  source:
    repository: cfbuildpacks/cron-resource

- name: bosh-deployment
  type: docker-image
  source:
    repository: cloudfoundry/bosh-deployment-resource

- name: semver-latest
  type: docker-image
  source:
    repository: concourse/semver-resource
    tag: latest

resources:
#@ for buildpack in buildpacks:
- name: #@ buildpack + "-buildpack-release"
  type: git
  source:
    branch: master
    uri: #@ "https://github.com/cloudfoundry/{}-buildpack-release.git".format(buildpack)
#@ end

# ... (continue with all resources, replacing cflinuxfs4 with cflinuxfs5)

- name: cflinuxfs5
  type: git
  source:
    branch: main
    uri: git@github.com:cloudfoundry/cflinuxfs5.git
    private_key: ((cf-buildpacks-eng-github-ssh-key.private_key))

- name: cflinuxfs5-github-tags
  type: git
  source:
    uri: git@github.com:cloudfoundry/cflinuxfs5.git
    private_key: ((cf-buildpacks-eng-github-ssh-key.private_key))
    tag_filter: "*"

# ... (continue with all other resources)

- name: new-cves-trigger
  type: git
  source:
    uri: git@github.com:cloudfoundry/public-buildpacks-ci-robots
    branch: main
    paths:
      - new-cve-notifications/ubuntu24.04.yml
      - new-cve-notifications/ubuntu24.04-unrelated.yml
    private_key: ((cf-buildpacks-eng-github-ssh-key.private_key))

- name: gcp-stemcell
  type: bosh-io-stemcell
  source:
    name: bosh-google-kvm-ubuntu-noble-go_agent  # Update when Noble stemcell is available

jobs:
- name: new-rootfs-cves
  serial: true
  public: true
  plan:
    - in_parallel:
        - get: buildpacks-ci
        - get: new-cves
        - get: rootfs
          resource: cflinuxfs5
        - get: check-interval
          trigger: true
    - in_parallel:
        - do:
            # Use stack-agnostic CVE task
            - task: check-for-new-cflinuxfs5-cves
              file: buildpacks-ci/tasks/check-for-new-rootfs-cves/task.yml
              input_mapping:
                rootfs: cflinuxfs5
              params:
                STACK: cflinuxfs5
                UBUNTU_VERSION: "Ubuntu 24.04"
                UBUNTU_CODENAME: ubuntu24.04
              output_mapping:
                output-new-cves: output-new-cves-cflinuxfs5
            - put: new-cves-cflinuxfs5
              resource: new-cves
              params:
                repository: output-new-cves-cflinuxfs5
                rebase: true

# ... (continue with all other jobs, replacing cflinuxfs4 with cflinuxfs5)
```

#### 3.2 Update Pipeline Update Script

**File:** `bin/update-pipelines`

Add cflinuxfs5 to the pipeline list (around line 138):

```bash
      if [[ "$pipeline_name" != "cflinuxfs4" && "$pipeline_name" != "cflinuxfs5" ]]; then
        continue
      fi
```

And update the list display (around line 64):

```bash
      if [[ "$pipeline_name" == "cflinuxfs4" || "$pipeline_name" == "cflinuxfs5" ]]; then
        echo "  - $pipeline_name"
      fi
```

### Phase 4: Buildpack Pipeline Updates

#### 4.1 Update Buildpack Values Files

For each buildpack that should support cflinuxfs5, update its values file:

**Files to update:**
- `pipelines/buildpack/apt-values.yml`
- `pipelines/buildpack/binary-values.yml`
- `pipelines/buildpack/dotnet-core-values.yml`
- `pipelines/buildpack/go-values.yml`
- `pipelines/buildpack/java-values.yml`
- `pipelines/buildpack/nginx-values.yml`
- `pipelines/buildpack/nodejs-values.yml`
- `pipelines/buildpack/php-values.yml`
- `pipelines/buildpack/python-values.yml`
- `pipelines/buildpack/r-values.yml`
- `pipelines/buildpack/ruby-values.yml`
- `pipelines/buildpack/staticfile-values.yml`

Example change for `python-values.yml`:

```yaml
#@data/values
---
language: python
organization: cloudfoundry

buildpack:
  stacks:
  - cflinuxfs4
  - cflinuxfs5  # Add this line
  product_slug: python-buildpack
  skip_docker_start: true
  skip_brats: true
  compute_instance_count: 1
```

#### 4.2 Update Buildpack Pipeline Template

**File:** `pipelines/buildpack/pipeline.yml`

Add cflinuxfs5 version resource (around line 199):

```yaml
  - name: version-stack-cflinuxfs5
    type: semver
    source:
      bucket: cflinuxfs5-release
      key: versions/stack-cflinuxfs5
      access_key_id: ((buildpacks-cloudfoundry-org-aws-access-key-id))
      secret_access_key: ((buildpacks-cloudfoundry-org-aws-secret-access-key))
```

Update the integration test job to get the appropriate version resource (around line 522):

```yaml
      #@ if "cflinuxfs4" in data.values.buildpack.stacks:
      - get: version-stack-cflinuxfs4
      #@ end
      #@ if "cflinuxfs5" in data.values.buildpack.stacks:
      - get: version-stack-cflinuxfs5
      #@ end
```

### Phase 5: BRATS Pipeline Updates

#### 5.1 Update BRATS Configuration

**File:** `pipelines/brats/config.yml`

Add cflinuxfs5 to each language's stack list:

```yaml
#@data/values
---
languages:
- apt
- binary
- dotnet-core
- go
- nodejs
- python
- ruby
- staticfile
- php
- nginx

stacks:
  apt:
  - cflinuxfs4
  - cflinuxfs5
  binary:
  - cflinuxfs4
  - cflinuxfs5
  - windows
  dotnet-core:
  - cflinuxfs4
  - cflinuxfs5
  go:
  - cflinuxfs4
  - cflinuxfs5
  nginx:
  - cflinuxfs4
  - cflinuxfs5
  nodejs:
  - cflinuxfs4
  - cflinuxfs5
  php:
  - cflinuxfs4
  - cflinuxfs5
  python:
  - cflinuxfs4
  - cflinuxfs5
  ruby:
  - cflinuxfs4
  - cflinuxfs5
  staticfile:
  - cflinuxfs4
  - cflinuxfs5

tas_version: "4.0"
tas_pool_name: tas_four
current_timezone: America/New_York
```

### Phase 6: Infrastructure and Credentials

#### 6.1 AWS S3 Bucket

Create a new S3 bucket: `cflinuxfs5-release`

Required paths:
- `rootfs/` - For rootfs tarballs
- `versions/stack-cflinuxfs5` - For version tracking

#### 6.2 Credhub/Vault Credentials

Add the following credentials:
- `cflinuxfs5-lb-cert.certificate`
- `cflinuxfs5-lb-cert.private_key`

#### 6.3 DNS Configuration

Configure DNS for: `cflinuxfs5.buildpacks.ci.cloudfoundry.org`

#### 6.4 BBL State Directory

Create BBL state directory in `buildpacks-envs` repository:
- `cflinuxfs5/`

### Phase 7: cf-deployment Operations Files

Ensure cf-deployment has the necessary operations files:
- `operations/experimental/add-cflinuxfs5.yml`
- `operations/experimental/set-cflinuxfs5-default-stack.yml`

If these don't exist, they need to be created in the cf-deployment repository.

## Implementation Order

Execute the implementation in this order to minimize disruption:

1. **Phase 1** - Refactor tasks to be stack-agnostic (one-time effort)
2. **Phase 6** - Set up infrastructure (S3, credentials, DNS)
3. **Phase 2** - Update dependency builds configuration
4. **Phase 3** - Create cflinuxfs5 pipeline
5. **Phase 4** - Update buildpack pipelines (one at a time)
6. **Phase 5** - Update BRATS pipeline

## Testing Strategy

### Unit Testing
1. Run `ytt` validation on all modified pipeline files
2. Verify pipeline YAML syntax
3. Test stack-agnostic tasks with `STACK=cflinuxfs4` first (regression test)

### Integration Testing
1. Deploy cflinuxfs5 pipeline in dry-run mode
2. Test dependency builds for a single dependency (e.g., `go`)
3. Test one buildpack pipeline (e.g., `staticfile-buildpack`)
4. Run BRATS tests for one buildpack

### Rollout Strategy
1. Start with `staticfile-buildpack` (simplest)
2. Add `binary-buildpack`
3. Add remaining buildpacks one at a time
4. Monitor for build failures and dependency issues

## Rollback Plan

If issues are encountered:

1. Remove cflinuxfs5 from `build_stacks` in config.yml
2. Remove cflinuxfs5 from individual buildpack values files
3. Keep cflinuxfs5 pipeline but pause it
4. Investigate and fix issues before re-enabling

## Known Considerations

### Ubuntu 24.04 Compatibility Issues

1. **OpenSSL 3.x** - Some older language versions may not be compatible
   - Ruby < 3.1 may have issues
   - Python < 3.10 may have issues
   - Add appropriate `skip_lines_cflinuxfs5` entries

2. **glibc version** - Compiled binaries must be built against Ubuntu 24.04's glibc

3. **System library changes** - Some dependencies may need updated build scripts

### Stemcell Availability

The Noble Numbat stemcell (`bosh-google-kvm-ubuntu-noble-go_agent`) must be available before the cflinuxfs5 pipeline can run integration tests.

## File Change Summary

### New Files (Stack-Agnostic)
- `tasks/build-binary-new/` (entire directory - stack-agnostic)
- `tasks/check-for-new-rootfs-cves/` (entire directory - stack-agnostic)
- `pipelines/cflinuxfs5.yml`

### Modified Files
- `pipelines/dependency-builds/config.yml`
- `pipelines/dependency-builds/pipeline.yml`
- `pipelines/buildpack/pipeline.yml`
- `pipelines/buildpack/*-values.yml` (all buildpack values files)
- `pipelines/brats/config.yml`
- `bin/update-pipelines`

### Deprecated (To Be Removed Later)
- `tasks/build-binary-new-cflinuxfs4/` (replaced by stack-agnostic version)
- `tasks/check-for-new-rootfs-cves-cflinuxfs4/` (replaced by stack-agnostic version)

### Already Updated (No Changes Needed)
- `lib/rootfs-cve-feed.rb` (already supports cflinuxfs5)

## Benefits of Stack-Agnostic Approach

1. **No duplicate code** - Single task directory serves all stacks
2. **Easy to add new stacks** - Just add to config, no new task directories needed
3. **Reduced maintenance** - Bug fixes apply to all stacks automatically
4. **Consistent behavior** - All stacks use identical build logic
5. **Future-proof** - cflinuxfs6, cflinuxfs7, etc. require only config changes

## AI Implementation Notes

When implementing this guide with AI assistance:

1. **Start with Phase 1** - Create stack-agnostic tasks first
2. **Test with existing stack** - Verify `STACK=cflinuxfs4` works before adding cflinuxfs5
3. **Validate incrementally** - Run `ytt` validation after each pipeline change
4. **Test one buildpack first** - Use staticfile-buildpack as the test case
5. **Commit in logical chunks** - One commit per phase for easy rollback

### Implementation Checklist for AI

```markdown
## Phase 1: Stack-Agnostic Refactoring
- [ ] Create `tasks/build-binary-new/` directory
- [ ] Create stack-agnostic `build.yml` (no hardcoded image)
- [ ] Create stack-agnostic `build.sh` (uses $STACK)
- [ ] Create stack-agnostic `build.rb` (passes stack to wrapper)
- [ ] Create stack-agnostic `binary_builder_wrapper.rb` (accepts stack param)
- [ ] Update `builder.rb` to use $STACK for paths
- [ ] Copy supporting files (source_input.rb, etc.)
- [ ] Create `tasks/check-for-new-rootfs-cves/` directory
- [ ] Create stack-agnostic CVE task.yml
- [ ] Create stack-agnostic CVE run.rb
- [ ] Test with STACK=cflinuxfs4 (regression test)

## Phase 2: Configuration
- [ ] Add cflinuxfs5 entries to dependency-builds/config.yml
- [ ] Update build_stacks array
- [ ] Add skip_lines_cflinuxfs5 where needed

## Phase 3: Rootfs Pipeline
- [ ] Create pipelines/cflinuxfs5.yml
- [ ] Update bin/update-pipelines

## Phase 4: Buildpack Pipelines
- [ ] Add cflinuxfs5 to each *-values.yml file
- [ ] Update pipeline.yml for version-stack-cflinuxfs5

## Phase 5: BRATS
- [ ] Update brats/config.yml with cflinuxfs5 stacks

## Phase 6: Infrastructure (Manual)
- [ ] Create S3 bucket
- [ ] Add credentials to Credhub
- [ ] Configure DNS
- [ ] Create BBL state directory
```

## References

- [cflinuxfs4 repository](https://github.com/cloudfoundry/cflinuxfs4)
- [cflinuxfs4-release repository](https://github.com/cloudfoundry/cflinuxfs4-release)
- [Ubuntu 24.04 Release Notes](https://wiki.ubuntu.com/NobleNumbat/ReleaseNotes)
- [Cloud Foundry Buildpacks Documentation](https://docs.cloudfoundry.org/buildpacks/)
