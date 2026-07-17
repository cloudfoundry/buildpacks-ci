# Buildpacks CI Pipeline Architecture

This document provides a comprehensive overview of the Cloud Foundry Buildpacks team CI/CD pipelines.

**Concourse Instance:** https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/  
**Team:** `buildpacks-team`

---

## Quick Reference

| Pipeline | Purpose | Trigger | Key Output |
|----------|---------|---------|------------|
| `dependency-builds` | Build binaries from upstream sources | Hourly version checks | Compiled binaries in S3, PRs to buildpacks |
| `{language}-buildpack` | Test and release buildpacks | Git commits, merged PRs | Buildpack zips, GitHub releases |
| `cf-release` | Create BOSH releases for all buildpacks | Weekly (or manual) | BOSH release tarballs |
| `brats` | Nightly buildpack smoke tests | Daily cron | Test results |
| `buildpack-verification` | Verify binary integrity | Daily cron | Verification reports |
| `resources` | Build depwatcher Docker image | Changes to depwatcher code | `coredeps/depwatcher` image |

---

## Architecture Overview

The buildpacks CI/CD system consists of interconnected pipelines that handle the complete lifecycle from upstream dependency updates to final BOSH releases.

```
                         DEPENDENCY LIFECYCLE
    ┌─────────────────────────────────────────────────────────────┐
    │                                                             │
    │  ┌─────────────┐      ┌──────────────┐      ┌───────────┐  │
    │  │  Upstream   │ ───▶ │ dependency-  │ ───▶ │ {lang}-   │  │
    │  │  Sources    │      │   builds     │  PR  │ buildpack │  │
    │  │ (npm, PyPI, │      │              │      │           │  │
    │  │  Maven...)  │      └──────────────┘      └─────┬─────┘  │
    │  └─────────────┘                                  │        │
    │                                            published       │
    │                                                  │        │
    │                                                  ▼        │
    │                                          ┌───────────┐    │
    │                                          │ cf-release│    │
    │                                          │  (BOSH)   │    │
    │                                          └───────────┘    │
    │                                                           │
    └─────────────────────────────────────────────────────────────┘

                         QUALITY ASSURANCE
    ┌─────────────────────────────────────────────────────────────┐
    │                                                             │
    │  ┌─────────────┐              ┌─────────────────────────┐  │
    │  │    brats    │              │ buildpack-verification  │  │
    │  │  (nightly)  │              │       (daily)           │  │
    │  └─────────────┘              └─────────────────────────┘  │
    │                                                             │
    └─────────────────────────────────────────────────────────────┘
```

---

## Pipeline Details

### 1. Dependency Builds Pipeline

**Location:** `pipelines/dependency-builds/`  
**Concourse:** [dependency-builds](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/buildpacks-team/pipelines/dependency-builds)

#### Purpose

Monitors upstream dependency sources, builds stack-specific binaries, and creates PRs to update buildpack manifests.

#### How It Works

```
Step 1: Depwatcher resources poll upstream sources hourly
        (npm, PyPI, RubyGems, Maven, GitHub releases, etc.)
                              │
                              ▼
Step 2: New version detected → build-{dependency}-{version-line} job triggers
                              │
                              ▼
Step 3: Dependency compiled for each supported stack (cflinuxfs4, cflinuxfs5)
        inside stack-specific Docker containers
                              │
                              ▼
Step 4: Compiled binary uploaded to S3
        (buildpacks.cloudfoundry.org/dependencies/{dependency}/)
                              │
                              ▼
Step 5: update-{dependency}-{version-line}-{buildpack} job creates PR
        to update manifest.yml in the buildpack repo
```

#### Example Flow

```
Python 3.12.5 released on python.org
        │
        ▼
depwatcher detects new version
        │
        ▼
build-python-3.12 job runs
   - Compiles python-3.12.5-linux-x64-cflinuxfs4.tgz
   - Compiles python-3.12.5-linux-x64-cflinuxfs5.tgz
   - Uploads to S3
        │
        ▼
update-python-3.12-python-buildpack job
   - Creates PR to cloudfoundry/python-buildpack
   - Updates manifest.yml with new version + SHA256
```

#### Dependencies Managed

The pipeline manages **56 dependencies** including:

| Category | Examples |
|----------|----------|
| Languages | python, ruby, go, node, php, r, jruby |
| Runtimes | dotnet-sdk, dotnet-runtime, openjdk, zulu, sapmachine |
| Web Servers | nginx, httpd, openresty |
| Package Managers | pip, pipenv, bundler, rubygems, yarn, composer |
| Java Tools | tomcat, groovy, spring-boot-cli, maven |
| APM Agents | appdynamics, newrelic, datadog, dynatrace |

#### Artifacts Produced

- **Compiled binaries:** `https://buildpacks.cloudfoundry.org/dependencies/{dependency}/{dependency}-{version}-{stack}.tgz`
- **Build metadata:** Stored in `public-buildpacks-ci-robots` repository
- **Pull requests:** Against buildpack repositories to update `manifest.yml`

> **Note:** S3 bucket `buildpacks.cloudfoundry.org` is accessible via HTTPS URLs shown above.

#### Configuration

- **Main config:** `pipelines/dependency-builds/config.yml`
- Contains all dependency definitions, version lines, stack mappings, and buildpack associations

---

### 2. Buildpack Pipelines

**Location:** `pipelines/buildpack/`  
**Template:** `pipeline.yml` + `{language}-values.yml`

#### Available Buildpack Pipelines

| Pipeline | Repository | Stacks |
|----------|------------|--------|
| `python-buildpack` | cloudfoundry/python-buildpack | cflinuxfs4, cflinuxfs5 |
| `ruby-buildpack` | cloudfoundry/ruby-buildpack | cflinuxfs4, cflinuxfs5 |
| `go-buildpack` | cloudfoundry/go-buildpack | cflinuxfs4, cflinuxfs5 |
| `nodejs-buildpack` | cloudfoundry/nodejs-buildpack | cflinuxfs4, cflinuxfs5 |
| `php-buildpack` | cloudfoundry/php-buildpack | cflinuxfs4, cflinuxfs5 |
| `java-buildpack` | cloudfoundry/java-buildpack | cflinuxfs4, cflinuxfs5 |
| `dotnet-core-buildpack` | cloudfoundry/dotnet-core-buildpack | cflinuxfs4, cflinuxfs5 |
| `staticfile-buildpack` | cloudfoundry/staticfile-buildpack | cflinuxfs4, cflinuxfs5 |
| `binary-buildpack` | cloudfoundry/binary-buildpack | cflinuxfs4, cflinuxfs5 |
| `nginx-buildpack` | cloudfoundry/nginx-buildpack | cflinuxfs4, cflinuxfs5 |
| `r-buildpack` | cloudfoundry/r-buildpack | cflinuxfs4, cflinuxfs5 |
| `apt-buildpack` | cloudfoundry/apt-buildpack | cflinuxfs4, cflinuxfs5 |
| `hwc-buildpack` | cloudfoundry/hwc-buildpack | windows |

#### Pipeline Stages

| Stage | Job(s) | Description |
|-------|--------|-------------|
| **Unit Tests** | `specs-unit` | Run Ginkgo unit tests |
| **Integration Tests** | `specs-switchblade-docker-{stack}` | Run integration tests in Docker using [Switchblade](https://github.com/cloudfoundry/switchblade) framework |
| **Build Artifacts** | `detect-new-version-and-upload-artifacts` | Build cached & uncached buildpack zips, upload to S3 |
| **Full CF Tests** | `create-cf-infrastructure-and-execute-integration-test` | Deploy full CF environment, run BRATS & integration tests |
| **Release** | `ship-it` (manual trigger) | Create GitHub release, bump version |
| **Dependency Updates** | `update-libbuildpack` | Create PR to update libbuildpack when it changes |

> **Note:** [Switchblade](https://github.com/cloudfoundry/switchblade) is a testing framework that allows running buildpack integration tests against both Docker and real CF environments using the same test code.

#### Triggers

- Git commits to the buildpack repository (master/main branch)
- Merged PRs from dependency-builds pipeline
- libbuildpack changes (for `update-libbuildpack` job)

#### Artifacts Produced

| Artifact | Location | Example |
|----------|----------|---------|
| Uncached buildpack | S3 release candidates | `python_buildpack-cflinuxfs4-v1.8.21.zip` |
| Cached buildpack | S3 release candidates | `python_buildpack-cached-cflinuxfs4-v1.8.21.zip` |
| GitHub release | buildpack repo | `v1.8.21` tag with release notes |

#### BOSH Deployment in Buildpack Pipelines

The `create-cf-infrastructure-and-execute-integration-test` job performs a full CF deployment:

1. **BBL Up:** Creates GCP infrastructure using BOSH Bootloader
2. **Deploy CF:** Deploys Cloud Foundry using cf-deployment
3. **Run Tests:** Executes BRATS and integration tests against deployed CF
4. **Cleanup:** Destroys infrastructure after tests complete

**Environment details:**

| Buildpack | BBL State Directory | System Domain |
|-----------|---------------------|---------------|
| python | `python-buildpack-state` | `python.buildpacks.ci.cloudfoundry.org` |
| ruby | `ruby-buildpack-state` | `ruby.buildpacks.ci.cloudfoundry.org` |
| go | `go-buildpack-state` | `go.buildpacks.ci.cloudfoundry.org` |
| ... | `{language}-buildpack-state` | `{language}.buildpacks.ci.cloudfoundry.org` |

BBL state is stored in the `cloudfoundry/buildpacks-envs` repository.

---

### 3. CF Release Pipeline

**Location:** `pipelines/cf-release/`  
**Concourse:** [cf-release](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/buildpacks-team/pipelines/cf-release)

#### Purpose

Creates and publishes BOSH releases for all buildpacks, testing them against a full CF deployment.

#### How It Works

```
Step 1: Weekly trigger (or manual ship-it)
                              │
                              ▼
Step 2: create-{language}-buildpack-dev-release
        (runs for each buildpack: python, ruby, go, nodejs, etc.)
        - Creates dev BOSH release tarball
        - Uploads to BOSH director
                              │
                              ▼
Step 3: deploy
        - BBL up (creates GCP infrastructure)
        - Deploys CF with ALL buildpack dev releases
        - Environment: releases-buildpack-state
        - Domain: releases.buildpacks.ci.cloudfoundry.org
                              │
                              ▼
Step 4: cats
        - Runs Cloud Foundry Acceptance Tests
        - Validates all buildpacks work together
                              │
                              ▼
Step 5: ship-it (MANUAL TRIGGER)
        - Gates the release process
        - Operator review before publishing
                              │
                              ▼
Step 6: publish-{language}-buildpack-release
        - Finalizes BOSH release
        - Creates GitHub release on {language}-buildpack-release repo
        - Uploads release tarball
```

#### BOSH Deployment Details

| Setting | Value |
|---------|-------|
| Environment Name | `releases-buildpack-bbl-env` |
| BBL State Directory | `releases-buildpack-state` |
| System Domain | `releases.buildpacks.ci.cloudfoundry.org` |
| GCP Project | `cf-buildpacks` |
| GCP Region | `europe-north1` |

#### Supported Buildpacks

BOSH releases are created for:
- dotnet-core, go, java, nginx, nodejs, php, python, r, ruby, staticfile, binary

#### Artifacts Produced

| Artifact | Location |
|----------|----------|
| BOSH release tarballs | S3: `buildpacks.cloudfoundry.org/bosh-release-candidates/` |
| Final releases | GitHub: `cloudfoundry/{language}-buildpack-release` |

---

### 4. BRATS Pipeline

**Location:** `pipelines/brats/`  
**Concourse:** [brats](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/buildpacks-team/pipelines/brats)

#### Purpose

Runs Buildpack Runtime Acceptance Tests nightly against the master branch of all buildpacks.

#### How It Works

- **Trigger:** Daily cron (6 AM EST)
- **Tests:** BRATS test suite from each buildpack
- **Environments:** 
  - TAS 4.0 LTS (via Shepherd)
  - cf-deployment edge (via Shepherd)

> **Note:** [Shepherd](https://v2.shepherd.run) is a Cloud Foundry Foundation service that provisions on-demand test environments for CI pipelines.

#### Buildpacks Tested

apt, binary, dotnet-core, go, nodejs, python, ruby, staticfile, php, nginx

---

### 5. Buildpack Verification Pipeline

**Location:** `pipelines/buildpack-verification/`  
**Concourse:** [buildpack-verification](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/buildpacks-team/pipelines/buildpack-verification)

#### Purpose

Daily verification of buildpack binary integrity and checksums.

#### How It Works

- **Trigger:** Daily cron (6 AM)
- **Action:** Verifies all buildpack binaries match expected checksums
- **Buildpacks:** go, nodejs, ruby, python, php, staticfile, binary, dotnet-core, hwc

---

### 6. Resources Pipeline (Supporting)

**Location:** `pipelines/resources.yml`  
**Concourse:** [resources](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/buildpacks-team/pipelines/resources)

#### Purpose

Builds and publishes the `depwatcher` Docker image used by the `dependency-builds` pipeline to monitor upstream dependency versions.

#### How It Works

- **Trigger:** Changes to `dockerfiles/depwatcher-go/` directory
- **Action:** Builds and pushes `coredeps/depwatcher` image to DockerHub
- **Used by:** `dependency-builds` pipeline for version detection

---

## BOSH Deployment Environments Summary

All BOSH deployments use BBL (BOSH Bootloader) on GCP.

| Pipeline | Job | BBL State Directory | System Domain |
|----------|-----|---------------------|---------------|
| `{lang}-buildpack` | `create-cf-infrastructure...` | `{lang}-buildpack-state` | `{lang}.buildpacks.ci.cloudfoundry.org` |
| `cf-release` | `deploy` | `releases-buildpack-state` | `releases.buildpacks.ci.cloudfoundry.org` |

**State Repository:** [cloudfoundry/buildpacks-envs](https://github.com/cloudfoundry/buildpacks-envs)

---

## Artifacts Summary

| Artifact Type | Storage Location | Naming Convention |
|---------------|------------------|-------------------|
| Dependency binaries | `https://buildpacks.cloudfoundry.org/dependencies/` | `{dep}/{dep}-{version}-{stack}.tgz` |
| Buildpack zips (RC) | `https://buildpacks.cloudfoundry.org/buildpack-release-candidates/` | `{lang}_buildpack-{stack}-v{version}.zip` |
| Buildpack zips (final) | `https://buildpacks.cloudfoundry.org/buildpack-release-published/` | `{lang}_buildpack-{stack}-v{version}.zip` |
| BOSH releases | `https://buildpacks.cloudfoundry.org/bosh-release-candidates/` | `{lang}-buildpack-release-{version}.tgz` |
| GitHub releases | GitHub repositories | Tagged releases with tarballs |

> **Note:** All S3 artifacts are publicly accessible via the HTTPS URLs shown above.

---

## Key Repositories

### Buildpack Source Code

| Repository | Description |
|------------|-------------|
| [python-buildpack](https://github.com/cloudfoundry/python-buildpack) | Python buildpack |
| [ruby-buildpack](https://github.com/cloudfoundry/ruby-buildpack) | Ruby buildpack |
| [go-buildpack](https://github.com/cloudfoundry/go-buildpack) | Go buildpack |
| [nodejs-buildpack](https://github.com/cloudfoundry/nodejs-buildpack) | Node.js buildpack |
| [php-buildpack](https://github.com/cloudfoundry/php-buildpack) | PHP buildpack |
| [java-buildpack](https://github.com/cloudfoundry/java-buildpack) | Java buildpack |
| [dotnet-core-buildpack](https://github.com/cloudfoundry/dotnet-core-buildpack) | .NET Core buildpack |
| [staticfile-buildpack](https://github.com/cloudfoundry/staticfile-buildpack) | Static file buildpack |
| [binary-buildpack](https://github.com/cloudfoundry/binary-buildpack) | Binary buildpack |
| [nginx-buildpack](https://github.com/cloudfoundry/nginx-buildpack) | Nginx buildpack |
| [r-buildpack](https://github.com/cloudfoundry/r-buildpack) | R buildpack |
| [apt-buildpack](https://github.com/cloudfoundry/apt-buildpack) | APT buildpack |
| [hwc-buildpack](https://github.com/cloudfoundry/hwc-buildpack) | Windows HWC buildpack |

### BOSH Releases

| Repository | Description |
|------------|-------------|
| [go-buildpack-release](https://github.com/cloudfoundry/go-buildpack-release) | Go buildpack BOSH release |
| [python-buildpack-release](https://github.com/cloudfoundry/python-buildpack-release) | Python buildpack BOSH release |
| [ruby-buildpack-release](https://github.com/cloudfoundry/ruby-buildpack-release) | Ruby buildpack BOSH release |
| [nodejs-buildpack-release](https://github.com/cloudfoundry/nodejs-buildpack-release) | Node.js buildpack BOSH release |
| [php-buildpack-release](https://github.com/cloudfoundry/php-buildpack-release) | PHP buildpack BOSH release |
| [java-buildpack-release](https://github.com/cloudfoundry/java-buildpack-release) | Java buildpack BOSH release |
| [dotnet-core-buildpack-release](https://github.com/cloudfoundry/dotnet-core-buildpack-release) | .NET Core buildpack BOSH release |
| [staticfile-buildpack-release](https://github.com/cloudfoundry/staticfile-buildpack-release) | Static file buildpack BOSH release |
| [binary-buildpack-release](https://github.com/cloudfoundry/binary-buildpack-release) | Binary buildpack BOSH release |
| [nginx-buildpack-release](https://github.com/cloudfoundry/nginx-buildpack-release) | Nginx buildpack BOSH release |
| [r-buildpack-release](https://github.com/cloudfoundry/r-buildpack-release) | R buildpack BOSH release |

### Infrastructure & Tooling

| Repository | Description |
|------------|-------------|
| [buildpacks-ci](https://github.com/cloudfoundry/buildpacks-ci) | Pipeline definitions, tasks, scripts |
| [buildpacks-envs](https://github.com/cloudfoundry/buildpacks-envs) | BBL state for all environments |
| [libbuildpack](https://github.com/cloudfoundry/libbuildpack) | Shared Go library for buildpacks |
| [binary-builder](https://github.com/cloudfoundry/binary-builder) | Tool for building dependency binaries |
| [public-buildpacks-ci-robots](https://github.com/cloudfoundry/public-buildpacks-ci-robots) | CI state and metadata |

---

## Maintenance Tasks

### Releasing a Buildpack

1. Ensure all PRs from dependency-builds are merged
2. Wait for `{language}-buildpack` pipeline to go green
3. Navigate to the pipeline in Concourse
4. Trigger the `ship-it` job manually
5. Pipeline creates GitHub release with artifacts

### Creating BOSH Releases

1. The `cf-release` pipeline runs weekly automatically
2. Or manually trigger `trigger-buildpack-pipeline` job
3. Wait for `deploy` and `cats` jobs to pass
4. Trigger `ship-it` job manually
5. Individual `publish-{language}-buildpack-release` jobs create final releases

### Adding a New Dependency Version Line

1. Edit `pipelines/dependency-builds/config.yml`
2. Add new version line under the dependency section
3. Update pipeline:
   ```sh
   ./bin/update-pipelines -p dependency-builds
   ```

### Debugging a Failing Pipeline

1. Find the failing job in Concourse UI
2. Click on the failed task to view logs
3. To intercept a running/failed task:
   ```sh
   fly intercept -j {pipeline}/{job} -t {your-target} -n {task-name}
   ```
   > **Note:** Replace `{your-target}` with your configured fly target name (e.g., the name you used with `fly login`).
4. Check task inputs/outputs and environment

### Updating Pipeline Configuration

After modifying pipeline templates:

```sh
# Update specific pipeline
./bin/update-pipelines -p python-buildpack

# Update all buildpack pipelines
./bin/update-pipelines --buildpacks-only

# Update all pipelines
./bin/update-pipelines --all

# Dry run (validate without deploying)
./bin/update-pipelines -p python-buildpack --dry-run
```

See [README.md](../README.md) for more pipeline management commands.

---

## Pipeline Flow Diagram

Complete end-to-end flow from upstream dependency to BOSH release:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           EXTERNAL TRIGGERS                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐             │
│    │   Upstream    │    │  Git commits  │    │  Weekly/Daily │             │
│    │   versions    │    │  to buildpack │    │    timers     │             │
│    │  (npm, PyPI)  │    │     repos     │    │               │             │
│    └───────┬───────┘    └───────┬───────┘    └───────┬───────┘             │
│            │                    │                    │                      │
└────────────┼────────────────────┼────────────────────┼──────────────────────┘
             │                    │                    │
             ▼                    │                    │
┌─────────────────────────┐       │                    │
│   dependency-builds     │       │                    │
│   ─────────────────     │       │                    │
│   • Build binaries      │       │                    │
│   • Upload to S3        │       │                    │
│   • Create PRs          │───────┘                    │
└───────────┬─────────────┘                            │
            │ PR merged                                │
            ▼                                          │
┌─────────────────────────┐                            │
│   {language}-buildpack  │                            │
│   ────────────────────  │                            │
│   • Unit tests          │                            │
│   • Integration tests   │                            │
│   • Build artifacts     │                            │
│   • (Optional) CF deploy│                            │
│   • ship-it → release   │                            │
└───────────┬─────────────┘                            │
            │ published                                │
            ▼                                          ▼
┌─────────────────────────────────────────────────────────┐
│                      cf-release                          │
│                      ──────────                          │
│   • Create dev BOSH releases (all buildpacks)           │
│   • Deploy full CF environment                          │
│   • Run CATs                                            │
│   • ship-it (manual) → publish releases                 │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│              BOSH Releases Published                     │
│   ───────────────────────────────────                   │
│   • GitHub releases on {lang}-buildpack-release repos   │
│   • Release tarballs available for cf-deployment        │
└─────────────────────────────────────────────────────────┘


                    QUALITY ASSURANCE (parallel)
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   ┌─────────────────┐    ┌──────────────────────────┐  │
│   │      brats      │    │  buildpack-verification  │  │
│   │    (nightly)    │    │        (daily)           │  │
│   │                 │    │                          │  │
│   │  Run BRATS on   │    │  Verify binary           │  │
│   │  TAS + CF Edge  │    │  checksums               │  │
│   └─────────────────┘    └──────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Additional Resources

- [README.md](../README.md) - Pipeline update commands and build instructions
- [Concourse Documentation](https://concourse-ci.org/docs.html) - General Concourse CI documentation
- [ytt Documentation](https://carvel.dev/ytt/) - Template tool used for pipeline generation
- [BBL Documentation](https://github.com/cloudfoundry/bosh-bootloader) - BOSH Bootloader for infrastructure
