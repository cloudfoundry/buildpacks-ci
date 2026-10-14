# Java Buildpack Dependencies — Open Items

**Date:** 2026-10-12
**Supersedes:** `docs/missing-java-dependencies-analysis.md` (2026-02-13) and the
open items of the migration plan in #599 (2026-03-31).

Most java-buildpack dependencies are now built by the `dependency-builds` pipeline
(`pipelines/dependency-builds/config.yml`) and served from `buildpacks.cloudfoundry.org`.
This document lists only the manifest entries that are not, and what to do with them.
All dependencies listed as missing in the old analysis now have a `config.yml` entry,
except those below; of these, only `google-stackdriver-profiler` and `metric-writer` have one.

## Current state

Of the 47 dependency entries in the java-buildpack `manifest.yml`, 35 are on
`buildpacks.cloudfoundry.org` with a `config.yml` entry. The remaining 12 are below.

| Dependency | Version | Hosted on | Proposed action |
|---|---|---|---|
| `memory-calculator` | 4.2.0 | `java-buildpack.cloudfoundry.org` | Add watcher (see todo) |
| `memory-calculator` | 4.1.0 | GitHub releases | Remove (unused) |
| `tomcat-access-logging-support` | 3.4.0 | `java-buildpack.cloudfoundry.org` | Add watcher (see todo) |
| `tomcat-lifecycle-support` | 3.4.0 | `java-buildpack.cloudfoundry.org` | Add watcher (see todo) |
| `tomcat-logging-support` | 3.4.0 | `java-buildpack.cloudfoundry.org` | Add watcher (see todo) |
| `jvmkill` | 1.17.0 | `java-buildpack.cloudfoundry.org` | Add watcher (see todo) |
| `luna-security-provider` | 7.4.0 | `java-buildpack.cloudfoundry.org` | Keep, manual only |
| `google-stackdriver-profiler` | 0.4.0 | `storage.googleapis.com` | None, has `config.yml` entry |
| `metric-writer` | 3.5.0 | `java-buildpack.cloudfoundry.org` | Decide: remove |
| `auto-reconfiguration` | 2.12.0 | `java-buildpack.cloudfoundry.org` | Remove |
| `java-memory-assistant` | 0.5.0 | GitHub releases (SAP) | Decide, see below |
| `java-memory-assistant-cleanup` | 0.1.0 | GitHub releases (SAP) | Decide, see below |

## To be watched (CF-owned) and manual

The CF-owned ones should be watched, so new releases reach the buildpack (e.g. a new
`memory-calculator` release is planned). They have no GitHub releases to watch yet, so their
source repos need to publish them first (see the todo list below).

`java-buildpack.cloudfoundry.org` is the repository of the Ruby java-buildpack (an
`index.yml` per dependency, filled by the Concourse `ci/` scripts of each source repo). The
Go java-buildpack manifest kept these existing URIs. The Go buildpack only uses the
manifest `uri` and `sha256`, so moving a dependency to `buildpacks.cloudfoundry.org` is a
manifest change only. Keep the files on `java-buildpack.cloudfoundry.org`: older buildpack
releases still point at them.

- **`memory-calculator` 4.2.0**: the version the buildpack uses (see below).
  `cloudfoundry/java-buildpack-memory-calculator` has a `v4.2.0` tag, but its latest GitHub
  release is 4.1.0 (2020). A new release is planned; first in line.
- **`tomcat-*-support` 3.4.0**: CF Tomcat support libraries, unchanged for years.
- **`jvmkill` 1.17.0**: native agent, last release 2022, feature-complete.
- **`luna-security-provider` 7.4.0**: proprietary Thales Luna HSM client, not publicly
  redistributable. Manual updates only.

## No action needed

- **`google-stackdriver-profiler` 0.4.0**: already has a `config.yml` entry
  (`google-stackdriver-profiler`, source type `stackdriver_profiler`). There has been no new upstream version since, so the entry still
  points at the vendor URL. The next upstream release moves it to our bucket. Upstream is
  superseded by Google Cloud Profiler; consider removal separately.

## Decide: `java-memory-assistant`

`java-memory-assistant` 0.5.0 (Java agent) and `java-memory-assistant-cleanup` 0.1.0 (Go
helper that removes old dumps) create heap dumps when a memory pool crosses a threshold,
e.g. `old_gen > 800MB` or `+20%/2m`. It is still in use. The source repos moved to
`SAP-archive` and were archived in September 2023; the last release is from 2020 and no fork
is active. Supported JVMs are documented up to HotSpot 11; on an unsupported JVM the agent
disables itself, and memory pool names differ for newer collectors (e.g. generational ZGC).

Built-in alternatives cover only part of it: `-XX:+HeapDumpOnOutOfMemoryError` and `jvmkill`
dump on out-of-memory, `cf ssh` + `jcmd <pid> GC.heap_dump` dumps on demand, and JFR
(`OldObjectSample`) helps find leaks. None dump on a usage threshold.

Options:

1. **Keep frozen**: leave 0.5.0 in the manifest; works on JVMs where the pool names match.
2. **Fork to `cloudfoundry`** (Apache-2.0): modernize build and tests for current JDKs, add
   GitHub Actions releases, a watcher and a recipe. Needs an owner.
3. **New, smaller agent** with the same features: thresholds by polling JDK
   `MemoryPoolMXBean` usage (needed for growth rules like `+20%/2m`), dumps via `HotSpotDiagnosticMXBean`,
   GC-agnostic pool selection and dump rotation built in (no separate cleanup binary). Keeps
   the buildpack configuration (`JBP_CONFIG_JAVA_MEMORY_ASSISTANT`) compatible. Instead of
   polling, it can subscribe to JFR GC events (e.g. `jdk.GCHeapSummary`, heap used after each
   GC) via JFR event streaming; that needs JDK 14+, so Java 8 and 11 would still poll.
4. **Remove** from the buildpack and document the alternatives above.

## Removal candidates

Removal is a java-buildpack change (manifest and any component code); listed here because
it determines whether pipeline work is needed.

- **`memory-calculator` 4.1.0**: unused. The buildpack resolves `memory-calculator`
  through `DefaultVersion` with the default `4.x` line, which always picks 4.2.0. Only an app
  explicitly pinning 4.1.0 would use it.
- **`auto-reconfiguration` 2.12.0**: Spring Cloud Connectors was deprecated in 2019 and
  replaced by `java-cfenv`. No GitHub releases, not on Maven Central.
- **`metric-writer` 3.5.0**: backs the discontinued PCF Metrics Forwarder. It has a
  `config.yml` entry (`github_tags`), but the repo has had no release since 3.5.0. Decide
  whether to remove it from the manifest and from `config.yml`.

## Todo: modernize CF-owned source repos

Same approach as `java-buildpack-client-certificate-mapper` and
`java-buildpack-security-provider`: dependency updates, GitHub Actions CI and tag-triggered
release workflows that attach the artifact to a GitHub release, then a `github_releases`
watcher in `config.yml` and a recipe in `cloudfoundry/binary-builder` (see
[How to add a new dependency](../pipelines/dependency-builds/README.md#how-to-add-a-new-dependency)). This replaces the old
Concourse `ci/` scripts and moves the artifact from `java-buildpack.cloudfoundry.org` to our
bucket.

| Repo | Manifest entries | Last activity | Status |
|---|---|---|---|
| `cloudfoundry/java-buildpack-client-certificate-mapper` | `client-certificate-mapper` | 2026 | ✅ Done (v2.1.0) |
| `cloudfoundry/java-buildpack-security-provider` | `container-security-provider` | 2026 | ✅ Done (v1.21.0) |
| `cloudfoundry/java-buildpack-support` | `tomcat-access-logging-support`, `tomcat-lifecycle-support`, `tomcat-logging-support` | 2023, no GitHub releases | Todo |
| `cloudfoundry/java-buildpack-memory-calculator` (Go) | `memory-calculator` | 2024, tag `v4.2.0` without a release | Todo |
| `cloudfoundry/jvmkill` (Rust, native) | `jvmkill` | 2022 | Todo; needs a native build per stack |

`cloudfoundry/java-buildpack-auto-reconfiguration` and
`cloudfoundry/java-buildpack-metric-writer` are left out: they are removal candidates.
