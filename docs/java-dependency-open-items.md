# Java Buildpack Dependencies — Open Items

**Date:** 2026-10-07
**Supersedes:** `docs/missing-java-dependencies-analysis.md` (2026-02-13) and the
open items of the migration plan in #599 (2026-03-31).

Most java-buildpack dependencies are now built by the `dependency-builds` pipeline
(`pipelines/dependency-builds/config.yml`) and served from `buildpacks.cloudfoundry.org`.
This document lists only the manifest entries that are not, and what to do with them.
All dependencies listed as missing in the old analysis now have a `config.yml` entry,
except those below.

## Current state

Of the 47 dependency entries in the java-buildpack `manifest.yml`, 34 are on
`buildpacks.cloudfoundry.org` with a `config.yml` entry. The remaining 13 are below.

| Dependency | Version | Hosted on | Proposed action |
|---|---|---|---|
| `container-security-provider` | 1.20.0 | `java-buildpack.cloudfoundry.org` | Being replaced, see below |
| `memory-calculator` | 4.2.0 | `java-buildpack.cloudfoundry.org` | Keep (frozen) |
| `memory-calculator` | 4.1.0 | GitHub releases | Remove (unused) |
| `tomcat-access-logging-support` | 3.4.0 | `java-buildpack.cloudfoundry.org` | Keep (frozen) |
| `tomcat-lifecycle-support` | 3.4.0 | `java-buildpack.cloudfoundry.org` | Keep (frozen) |
| `tomcat-logging-support` | 3.4.0 | `java-buildpack.cloudfoundry.org` | Keep (frozen) |
| `jvmkill` | 1.17.0 | `java-buildpack.cloudfoundry.org` | Keep (frozen) |
| `luna-security-provider` | 7.4.0 | `java-buildpack.cloudfoundry.org` | Keep, manual only |
| `google-stackdriver-profiler` | 0.4.0 | `storage.googleapis.com` | None, has `config.yml` entry |
| `metric-writer` | 3.5.0 | `java-buildpack.cloudfoundry.org` | Decide: remove |
| `auto-reconfiguration` | 2.12.0 | `java-buildpack.cloudfoundry.org` | Remove |
| `java-memory-assistant` | 0.5.0 | GitHub releases (SAP) | Decide, see below |
| `java-memory-assistant-cleanup` | 0.1.0 | GitHub releases (SAP) | Decide, see below |

## In progress

- **`container-security-provider`**: the source repo
  (`cloudfoundry/java-buildpack-security-provider`) now publishes GitHub releases, starting
  with `v1.21.0`. Watcher (#683) and recipe (cloudfoundry/binary-builder#123) are merged;
  the pipeline replaces the 1.20.0 entry with 1.21.0.

## Keep as-is (frozen artifacts)

These have no upstream releases to watch. `java-buildpack.cloudfoundry.org` is a host we
control, so no migration or `config.yml` entry is needed for now. The CF-owned ones can move
to the pipeline once their source repos publish GitHub releases (see the todo list below).

- **`memory-calculator` 4.2.0**: the version the buildpack uses (see below).
  `cloudfoundry/java-buildpack-memory-calculator` has a `v4.2.0` tag, but its latest GitHub
  release is 4.1.0 (2020).
- **`tomcat-*-support` 3.4.0**: CF Tomcat support libraries, unchanged for years.
- **`jvmkill` 1.17.0**: native agent, last release 2022, feature-complete.
- **`luna-security-provider` 7.4.0**: proprietary Thales Luna HSM client, not publicly
  redistributable. Manual updates only.

## No action needed

- **`google-stackdriver-profiler` 0.4.0**: already has a `config.yml` entry
  (`stackdriver_profiler`). There has been no new upstream version since, so the entry still
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
3. **New, smaller agent** with the same features: thresholds via the JDK
   `MemoryPoolMXBean` usage threshold notifications, dumps via `HotSpotDiagnosticMXBean`,
   GC-agnostic pool selection and dump rotation built in (no separate cleanup binary). Keeps
   the buildpack configuration (`JBP_CONFIG_JAVA_MEMORY_ASSISTANT`) compatible.
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
