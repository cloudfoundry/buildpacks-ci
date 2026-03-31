# Java Buildpack Dependency Migration Plan

**Date:** 2026-03-31  
**Purpose:** Document which java-buildpack manifest dependencies need to be migrated to
`buildpacks.cloudfoundry.org` S3, which need new `config.yml` entries in the
dependency-builds pipeline, and which are EOL or deprecated.

Supersedes: `docs/missing-java-dependencies-analysis.md` (2026-02-13)

---

## Background

The java-buildpack manifest currently hosts dependencies across several locations:

| Bucket / Host | Description |
|---|---|
| `buildpacks.cloudfoundry.org` | **Our S3 bucket** — the target for all dependencies |
| `java-buildpack.cloudfoundry.org` | Legacy java-buildpack CDN — not our S3, needs migration |
| `github.com` releases | Direct vendor/upstream download — not our S3 |
| `repo1.maven.org` | Maven Central — direct download, not our S3 |
| Vendor-hosted URLs | Commercial or custom vendor CDNs — not our S3 |

The dependency-builds pipeline exists to automate the process of watching upstream sources,
building or mirroring artifacts, uploading them to `buildpacks.cloudfoundry.org`, and opening
pull requests to update the manifest. Every dependency not on our S3 is a gap in that pipeline.

---

## Status Legend

| Symbol | Meaning |
|---|---|
| ✅ | On our S3 already — no migration needed |
| 🔄 | On `java-buildpack.cloudfoundry.org` — needs migration to our S3 |
| ⬇️ | Direct vendor/upstream download — needs migration to our S3 |
| 🟢 | Actively developed upstream (released 2025+) |
| 🟡 | Maintained but slow (last release 2023–2024) |
| 🔴 | Stale or EOL — no new releases since before 2023 |
| 🗄️ | Source repository archived — no longer maintained |
| ❌ | Should be removed from the manifest |
| 🔒 | **Always keep** — must never be removed regardless of upstream activity |

---

## Section 1 — Already on `buildpacks.cloudfoundry.org` (No Migration Needed)

These 16 entries are already served from our S3 bucket and have working `config.yml` entries
in the dependency-builds pipeline.

| Dependency | Versions in Manifest | config.yml `source_type` | Notes |
|---|---|---|---|
| `openjdk` | 8.0.482, 11.0.30, 17.0.18, 21.0.10, 25.0.2 | `liberica` | ✅ Fully automated |
| `zulu` | 8.0.482, 11.0.30, 17.0.18 | `zulu` | ✅ Fully automated |
| `sapmachine` | 17.0.18, 21.0.10, 25.0.2 | `github_releases` (SAP/SapMachine) | ✅ Fully automated |
| `tomcat` | 10.1.52, 11.0.20 | `tomcat` | ✅ Fully automated (10.1.x and 11.0.x lines) |
| `skywalking-agent` | 9.6.0 | `skywalking` | ✅ Fully automated |
| `jprofiler-profiler` | 15.0.4 | `jprofiler` | ✅ Fully automated |
| `your-kit-profiler` | 2025.9.191 | `yourkit` | ✅ Fully automated |

> **Note on `tomcat` 9.0.113:** The manifest also contains a `tomcat 9.0.113` entry that is
> **still served from `java-buildpack.cloudfoundry.org`**, not our S3. Tomcat 9.0.x is
> officially supported upstream until 2027-03-31. See Section 2 for the migration decision.

---

## Section 2 — On `java-buildpack.cloudfoundry.org` — Needs Migration

These 17 entries are hosted on the legacy `java-buildpack.cloudfoundry.org` CDN. They need to
be moved to `buildpacks.cloudfoundry.org` and added to `config.yml`.

### 2a — Active, needs new `config.yml` entry

These are actively maintained upstream and straightforward to automate.

#### `groovy` — 🟢 Active (4.0.x current, latest patch 4.0.31)

```
Current URI:  https://java-buildpack.cloudfoundry.org/groovy/groovy-4.0.29.zip
Source:       https://groovy.jfrog.io/artifactory/dist-release-local/groovy-zips/apache-groovy-binary-4.0.29.zip
```

Proposed `config.yml` entry:
```yaml
groovy:
  buildpacks:
    java:
      lines:
        - line: 4.0.X
  source_type: github_releases
  source_params:
    - 'repo: apache/groovy'
    - 'glob: apache-groovy-binary-*.zip'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true  # Apache Groovy doesn't publish formal EOL schedule
```

---

#### `jacoco` — 🟢 Active (latest 0.8.14, released Oct 2025)

```
Current URI:  https://java-buildpack.cloudfoundry.org/jacoco/jacoco-0.8.14.jar
Source:       https://repo1.maven.org/maven2/org/jacoco/jacoco/0.8.14/jacoco-0.8.14.zip
```

Proposed `config.yml` entry:
```yaml
jacoco:
  buildpacks:
    java:
      lines:
        - line: 0.8.X
  source_type: maven
  source_params:
    - 'group_id: org.jacoco'
    - 'artifact_id: org.jacoco.agent'
    - 'packaging: jar'
    - 'classifier: runtime'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true
```

---

#### `java-cfenv` — 🟢 Active (v4.0.0 released Feb 2026, breaking change from 3.x)

```
Current URI:  https://java-buildpack.cloudfoundry.org/java-cfenv/java-cfenv-3.5.0.jar
Source:       https://repo1.maven.org/maven2/io/pivotal/cfenv/java-cfenv/3.5.0/java-cfenv-3.5.0.jar
```

> ⚠️ **Version line decision required:** `v4.0.0` upgrades to Spring Boot 4.x and Jackson 3.x.
> This is a breaking change for apps still on Spring Boot 2.x/3.x. The buildpack team should
> decide whether to track `3.X.X` (current stable for older apps) and/or `4.X.X` (new line for
> Spring Boot 4 apps). The default in `manifest.yml` is `3.x` — consider whether to add a `4.x`
> line alongside it.

Proposed `config.yml` entry:
```yaml
java-cfenv:
  buildpacks:
    java:
      lines:
        - line: 3.X.X
        - line: 4.X.X
  source_type: maven
  source_params:
    - 'group_id: io.pivotal.cfenv'
    - 'artifact_id: java-cfenv'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true
```

---

#### `mariadb-jdbc` — 🟢 Active (latest 3.5.7, actively maintained)

```
Current URI:  https://java-buildpack.cloudfoundry.org/mariadb-jdbc/mariadb-jdbc-3.5.7.jar
Source:       https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.5.7/mariadb-java-client-3.5.7.jar
```

Proposed `config.yml` entry:
```yaml
mariadb-jdbc:
  buildpacks:
    java:
      lines:
        - line: 3.X.X
  source_type: maven
  source_params:
    - 'group_id: org.mariadb.jdbc'
    - 'artifact_id: mariadb-java-client'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true
```

---

#### `postgresql-jdbc` — 🟢 Active (latest 42.7.8, actively maintained)

```
Current URI:  https://java-buildpack.cloudfoundry.org/postgresql-jdbc/postgresql-jdbc-42.7.8.jar
Source:       https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.8/postgresql-42.7.8.jar
```

Proposed `config.yml` entry:
```yaml
postgresql-jdbc:
  buildpacks:
    java:
      lines:
        - line: 42.X.X
  source_type: maven
  source_params:
    - 'group_id: org.postgresql'
    - 'artifact_id: postgresql'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true
```

---

#### `tomcat-access-logging-support`, `tomcat-lifecycle-support`, `tomcat-logging-support` — ✅ No migration needed

```
Current URIs (all on java-buildpack.cloudfoundry.org):
  https://java-buildpack.cloudfoundry.org/tomcat-access-logging-support/tomcat-access-logging-support-3.4.0-RELEASE.jar
  https://java-buildpack.cloudfoundry.org/tomcat-lifecycle-support/tomcat-lifecycle-support-3.4.0-RELEASE.jar
  https://java-buildpack.cloudfoundry.org/tomcat-logging-support/tomcat-logging-support-3.4.0-RELEASE.jar
```

> ℹ️ These three CF-maintained Tomcat support libraries were last released at version 3.4.0
> and have not been updated since. The source repositories (`cloudfoundry/java-buildpack-support`)
> are effectively inactive. However, they are functionally stable and are bundled with every
> Tomcat deployment.
>
> Since `java-buildpack.cloudfoundry.org` is a host we control and these artifacts will never
> change, **no migration is needed**. Leave the manifest URIs pointing to
> `java-buildpack.cloudfoundry.org` as-is. No `config.yml` entry is required.

---

#### `spring-boot-cli` — ❌ EOL (2.7.x OSS EOL: 2023-06-30)

```
Current URI:  https://java-buildpack.cloudfoundry.org/spring-boot-cli/spring-boot-cli-2.7.18.tar.gz
Source:       https://repo1.maven.org/maven2/org/springframework/boot/spring-boot-cli/2.7.18/spring-boot-cli-2.7.18-bin.tar.gz
```

Spring Boot 2.7.x reached **OSS end-of-life on 2023-06-30**. `2.7.18` is the final release
in this line. The latest production release is 3.5.x (with 4.0.x in development). The
`spring-boot-cli` has been essentially deprecated as a deployment mechanism in favour of
Spring Boot's embedded container support.

> ⚠️ **Recommendation: Remove from manifest.** If a 3.x line is required, add a new entry
> pointing to the current 3.x Maven artifact instead of migrating the dead 2.7.x entry.

---

#### `memory-calculator` 4.2.0 — 🔒 Always keep, no migration needed

```
Current URI:  https://java-buildpack.cloudfoundry.org/memory-calculator/jammy/x86_64/memory-calculator-4.2.0.tgz
```

> ℹ️ There is no GitHub release or public source for version 4.2.0 — it was built and hosted
> directly on `java-buildpack.cloudfoundry.org`. Since that is a host we control and this
> artifact is frozen, **no migration is needed**. Leave the manifest URI as-is. No `config.yml`
> entry required. This dependency must always be kept in the manifest.

---

#### `container-security-provider` 1.20.0 — 🔒 Always keep, no migration needed

```
Current URI:  https://java-buildpack.cloudfoundry.org/container-security-provider/container-security-provider-1.20.0-RELEASE.jar
```

> ℹ️ `container-security-provider` is a CF-internal library required for CF security credential
> propagation. There is no public GitHub repository and no newer version has been published.
> Since `java-buildpack.cloudfoundry.org` is a host we control and this artifact is frozen,
> **no migration is needed**. Leave the manifest URI as-is. No `config.yml` entry required.
> This dependency must always be kept in the manifest.

---

#### `jvmkill` — 🟡 Stable, no new releases expected

```
Current URI:  https://java-buildpack.cloudfoundry.org/jvmkill/jammy/x86_64/jvmkill-1.17.0-RELEASE.so
Source:       https://github.com/cloudfoundry/jvmkill/releases/download/v1.17.0-RELEASE/jvmkill-1.17.0-RELEASE.so
```

`jvmkill` is a native C agent. The GitHub repo was last pushed in August 2022 and `v1.17.0`
is the last release. The project is considered feature-complete and stable — it is a low-level
`SIGKILL` handler that does not require frequent updates.

> **Action:** Mirror `jvmkill-1.17.0-RELEASE.so` to our S3 as a one-time static copy.
> No depwatcher entry needed (nothing to watch). Build must target the `jammy` (Ubuntu 22.04)
> C ABI to match cflinuxfs4/cflinuxfs5.

---

#### `luna-security-provider` — ⚫ Proprietary (Thales SafeNet HSM)

```
Current URI:  https://java-buildpack.cloudfoundry.org/luna-security-provider/LunaClient-Minimal-v7.4.0-226.x86_64.tar
```

> ℹ️ This is a proprietary Thales/SafeNet Luna HSM client library. It is not publicly
> redistributable. The artifact must remain on a private or controlled host.
>
> **Action:** If continued hosting is required, mirror to a private S3 path or keep on the
> existing CDN. No public pipeline automation is possible. Document as manual-only.

---

### 2b — `tomcat` 9.0.113 — ⚠️ Decision required

```
Current URI:  https://java-buildpack.cloudfoundry.org/tomcat/tomcat-9.0.113.tar.gz
Source:       https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.113/bin/apache-tomcat-9.0.113.tar.gz
```

Tomcat 9.0.x is officially supported until **2027-03-31**. The existing `config.yml` only
tracks `10.1.x` and `11.0.x`. The `9.0.x` entry also lags behind — the latest release is
`9.0.116`.

> **Decision options:**
> 1. **Add `9.0.X` line** to the existing `tomcat` config.yml entry and migrate to our S3.
> 2. **Drop `9.0.x`** from the manifest — Tomcat 10.1 and 11.0 are the supported lines.
>    Users requiring Tomcat 9 would need to use an older buildpack.
>
> Given the 2027 EOL, option 1 is reasonable if there is active user demand.

---

### 2c — Effectively abandoned CF projects — ❌ Recommend removal

#### `auto-reconfiguration` — ❌ Superseded by `java-cfenv`

```
Current URI:  https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-2.12.0-RELEASE.jar
Source:       (artifact not present on Maven Central — custom build only)
```

Spring Cloud Connectors (the library backing auto-reconfiguration) was
**deprecated in 2019** and superseded by `java-cfenv`. The GitHub source repo
(`cloudfoundry/java-buildpack-auto-reconfiguration`) has not been pushed since May 2022 and
has never cut a GitHub release. The artifact is not available on Maven Central.

> **Recommendation: Remove from manifest.** `java-cfenv` is the supported replacement.
> See `docs/spring-auto-reconfiguration-migration.md` in the java-buildpack repo for the
> migration guide.

---

#### `metric-writer` — ❌ Backs deprecated PCF Metrics product

```
Current URI:  https://java-buildpack.cloudfoundry.org/metric-writer/metric-writer-3.5.0-RELEASE.jar
Source:       (no GitHub releases, no Maven Central artifact)
```

`metric-writer` integrated with PCF Metrics Forwarder, a product that has been discontinued.
The GitHub repo (`cloudfoundry/java-buildpack-metric-writer`) was last pushed in September
2021 and has no releases. The artifact only exists on `java-buildpack.cloudfoundry.org`.

> **Recommendation: Remove from manifest.** The backing product is discontinued. If metrics
> are required, `cf-metrics-exporter` or an OpenTelemetry-based solution is the modern
> replacement.

---

## Section 3 — Direct Vendor Downloads — Needs Migration to Our S3

These entries download directly from GitHub releases, Maven Central, or commercial CDNs.
They need to be mirrored to `buildpacks.cloudfoundry.org` via new `config.yml` entries.

### 3a — GitHub Releases (active, straightforward to automate)

#### `azure-application-insights` — 🟢 Active (latest 3.7.8, Mar 2026)

```
Current URI:  https://github.com/microsoft/ApplicationInsights-Java/releases/download/3.6.2/applicationinsights-agent-3.6.2.jar
```

Proposed `config.yml` entry:
```yaml
azure-application-insights:
  buildpacks:
    java:
      lines:
        - line: 3.X.X
  source_type: github_releases
  source_params:
    - 'repo: microsoft/ApplicationInsights-Java'
    - 'glob: applicationinsights-agent-*.jar'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true
```

---

#### `open-telemetry-javaagent` — 🟢 Active (latest 2.26.1, Mar 2026)

```
Current URI:  https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.22.0/opentelemetry-javaagent.jar
```

Proposed `config.yml` entry:
```yaml
open-telemetry-javaagent:
  buildpacks:
    java:
      lines:
        - line: 2.X.X
  source_type: github_releases
  source_params:
    - 'repo: open-telemetry/opentelemetry-java-instrumentation'
    - 'glob: opentelemetry-javaagent.jar'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true
```

---

#### `splunk-otel-javaagent` — 🟢 Active (latest 2.26.1, Mar 2026)

```
Current URI:  https://github.com/signalfx/splunk-otel-java/releases/download/v2.22.0/splunk-otel-javaagent.jar
```

Proposed `config.yml` entry:
```yaml
splunk-otel-javaagent:
  buildpacks:
    java:
      lines:
        - line: 2.X.X
  source_type: github_releases
  source_params:
    - 'repo: signalfx/splunk-otel-java'
    - 'glob: splunk-otel-javaagent.jar'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true
```

---

#### `memory-calculator` 4.1.0 — 🔴 Stale (last release Jul 2020)

```
Current URI:  https://github.com/cloudfoundry/java-buildpack-memory-calculator/releases/download/v4.1.0/memory-calculator-4.1.0.tgz
```

> **Action:** Mirror as a static one-time copy to our S3. No depwatcher entry — the GitHub
> repo has not had a release since 2020. See also `4.2.0` in Section 2b.

---

#### `java-memory-assistant` — 🗄️ ARCHIVED (SAP-archive, Sep 2023)

```
Current URI:  https://github.com/SAP/java-memory-assistant/releases/download/0.5.0/java-memory-assistant-0.5.0.jar
```

The SAP GitHub repository was **archived on 2023-09-01** and moved to `SAP-archive/`.
No new releases will be published. Last release was `0.5.0` in March 2020.

> **Recommendation: Remove from manifest.** The project is archived and no longer maintained.

---

#### `java-memory-assistant-cleanup` — 🗄️ ARCHIVED (SAP-archive, Sep 2023)

```
Current URI:  https://github.com/SAP/java-memory-assistant-tools/releases/download/0.1.0/cleanup-linux-amd64-0.1.0.zip
```

The companion tools repository was also **archived on 2023-09-01** under `SAP-archive/`.
Last release was `0.1.0` in June 2017.

> **Recommendation: Remove from manifest.** Archived and inactive for 8+ years.

---

### 3b — Maven Central (active, straightforward to automate)

#### `datadog-javaagent` — 🟢 Active (manifest: 1.42.1, latest: 1.60.3, Mar 2026)

```
Current URI:  https://repo1.maven.org/maven2/com/datadoghq/dd-java-agent/1.42.1/dd-java-agent-1.42.1.jar
```

Proposed `config.yml` entry:
```yaml
datadog-javaagent:
  buildpacks:
    java:
      lines:
        - line: 1.X.X
  source_type: maven
  source_params:
    - 'group_id: com.datadoghq'
    - 'artifact_id: dd-java-agent'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true
```

---

#### `elastic-apm-agent` — 🟢 Active (manifest: 1.52.0, latest: 1.55.4, Jan 2026)

```
Current URI:  https://repo1.maven.org/maven2/co/elastic/apm/elastic-apm-agent/1.52.0/elastic-apm-agent-1.52.0.jar
```

Proposed `config.yml` entry:
```yaml
elastic-apm-agent:
  buildpacks:
    java:
      lines:
        - line: 1.X.X
  source_type: maven
  source_params:
    - 'group_id: co.elastic.apm'
    - 'artifact_id: elastic-apm-agent'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true
```

---

#### `cf-metrics-exporter` — ⚫ Unknown/community (no public GitHub repo found)

```
Current URI:  https://repo1.maven.org/maven2/io/github/rabobank/cf-metrics-exporter/0.7.1/cf-metrics-exporter-0.7.1.jar
```

> No public GitHub repository was found under `rabobank/cf-metrics-exporter`. This appears to
> be a community-maintained tool. Maven Central shows no listing for `io.github.rabobank`.
>
> **Action needed:** Verify the provenance of this artifact before automating. If it is a
> trusted dependency, add a `maven` watcher. Otherwise, consider removing it from the manifest.

---

### 3c — Commercial / Vendor-Hosted (manual or limited automation)

#### `newrelic` — 🟢 Active but major version behind (manifest: 8.15.0, latest: 9.1.0)

```
Current URI:  https://download.newrelic.com/newrelic/java-agent/newrelic-agent/8.15.0/newrelic-java-8.15.0.zip
```

New Relic Java agent is actively maintained. The manifest is on `8.x` while the latest
stable is `9.1.0` (Feb 2026). A major version bump may involve breaking API changes.

> **Decision required:** Upgrade to `9.x` line or maintain both `8.x` and `9.x`.
> New Relic publishes releases on GitHub (`newrelic/newrelic-java-agent`).

Proposed `config.yml` entry:
```yaml
newrelic:
  buildpacks:
    java:
      lines:
        - line: 9.X.X
  source_type: github_releases
  source_params:
    - 'repo: newrelic/newrelic-java-agent'
    - 'glob: newrelic-java-*.zip'
  any_stack: true
  versions_to_keep: 2
  skip_deprecation_check: true
```

---

#### `contrast-security` — 🟢 Active commercial agent (manifest: 6.23.0)

```
Current URI:  https://download.run.pivotal.io/contrast-security/contrast-agent-6.23.0.jar
```

Contrast Security is a commercial IAST/RASP security agent. It is actively maintained.
The download is hosted on a Pivotal CDN (`download.run.pivotal.io`) which may be unreliable
long-term. No public GitHub release page available for the agent JAR.

> **Action:** Investigate whether Contrast Security publishes releases via a public API or
> Maven repository. If not, document as manual-update only.

---

#### `jrebel` — 🟢 Active commercial agent (manifest: 2025.4.1)

```
Current URI:  https://dl.zeroturnaround.com/jrebel/releases/jrebel-2025.4.1-nosetup.zip
```

JRebel is a commercial hot-reload tool by Perforce (formerly ZeroTurnaround). It is actively
maintained but requires a commercial license. There is no public API for version discovery.

> **Action:** Document as manual-update only. A notification system or periodic check against
> `dl.zeroturnaround.com` may be possible but is not a priority.

---

#### `sealights-agent` — 🟢 Active commercial agent (manifest: 4.0.2570)

```
Current URI:  https://agents.sealights.co/sealights-java/sealights-java-4.0.2570.zip
```

SeaLights is a commercial test intelligence agent. The download URL uses a proprietary CDN.
No public release metadata is available.

> **Action:** Document as manual-update only.

---

#### `google-stackdriver-profiler` — 🟡 Active but superseded (manifest: 0.4.0, latest: 0.4.0)

```
Current URI:  https://storage.googleapis.com/cloud-profiler/java/latest/profiler_java_agent.tar.gz
```

> ⚠️ **The manifest URI uses a `latest` symlink** — there is no pinned version in the URL path.
> This makes SHA256 verification unreliable (the hash in the manifest will break whenever
> Google updates the `latest` pointer). The GitHub repo (`GoogleCloudPlatform/cloud-profiler-java`)
> shows `v0.4.0` as the current release (Oct 2024).
>
> Google Cloud Profiler is being superseded by OpenTelemetry-based profiling. The `0.x`
> default version line signals this is not a primary dependency.
>
> **Action:** Pin to the versioned `v0.4.0` download URL, mirror to our S3 as a static
> snapshot, and monitor the upstream repo for updates. No automated depwatcher needed at
> this time unless there is active demand.

---

## Section 4 — Removal Candidates

The following dependencies should be **removed from the manifest**. No S3 migration is needed.

| Dependency | Reason | Replacement |
|---|---|---|
| `java-memory-assistant` 0.5.0 | 🗄️ SAP-archive repo, archived Sep 2023. Last release 2020. | None (project discontinued) |
| `java-memory-assistant-cleanup` 0.1.0 | 🗄️ SAP-archive repo, archived Sep 2023. Last release 2017. | None (project discontinued) |
| `auto-reconfiguration` 2.12.0 | ❌ Spring Cloud Connectors deprecated 2019. No Maven artifact. | `java-cfenv` |
| `spring-boot-cli` 2.7.18 | ❌ Spring Boot 2.7.x OSS EOL: 2023-06-30. | Spring Boot 3.x CLI (`spring-boot-cli` 3.X.X line) |
| `metric-writer` 3.5.0 | ❌ PCF Metrics Forwarder discontinued. No Maven artifact. | `cf-metrics-exporter` or OpenTelemetry |

---

## Section 5 — Summary Action Table

### Migrate to `buildpacks.cloudfoundry.org` + add to `config.yml`

| Dependency | Current Host | `source_type` | Priority |
|---|---|---|---|
| `groovy` | `java-buildpack.c.o` | `github_releases` | 🔴 High |
| `jacoco` | `java-buildpack.c.o` | `maven` | 🟡 Medium |
| `java-cfenv` | `java-buildpack.c.o` | `maven` | 🔴 High |
| `mariadb-jdbc` | `java-buildpack.c.o` | `maven` | 🔴 High |
| `postgresql-jdbc` | `java-buildpack.c.o` | `maven` | 🔴 High |
| `azure-application-insights` | github.com | `github_releases` | 🔴 High |
| `open-telemetry-javaagent` | github.com | `github_releases` | 🔴 High |
| `splunk-otel-javaagent` | github.com | `github_releases` | 🔴 High |
| `datadog-javaagent` | Maven Central | `maven` | 🔴 High |
| `elastic-apm-agent` | Maven Central | `maven` | 🔴 High |
| `newrelic` | vendor CDN | `github_releases` | 🔴 High |

### Migrate to `buildpacks.cloudfoundry.org` as static one-time copy (no depwatcher)

| Dependency | Current Host | Reason |
|---|---|---|
| `jvmkill` 1.17.0 | `java-buildpack.c.o` | Stable C agent, no new releases expected |
| `memory-calculator` 4.1.0 | github.com | 🔒 Always keep; stale, last release 2020 — on GitHub so needs copying to our S3 |
| `google-stackdriver-profiler` 0.4.0 | `storage.googleapis.com` | Pin and mirror current version |
| `tomcat` 9.0.113 | `java-buildpack.c.o` | Add `9.0.X` line to existing `tomcat` config entry |

### No action needed — stable on `java-buildpack.cloudfoundry.org` (we control this host)

| Dependency | Version | Reason |
|---|---|---|
| `tomcat-access-logging-support` | 3.4.0 | Frozen artifact, hosted on our controlled CDN — no migration or pipeline entry needed |
| `tomcat-lifecycle-support` | 3.4.0 | Frozen artifact, hosted on our controlled CDN — no migration or pipeline entry needed |
| `tomcat-logging-support` | 3.4.0 | Frozen artifact, hosted on our controlled CDN — no migration or pipeline entry needed |
| `memory-calculator` 4.2.0 | 4.2.0 | 🔒 Always keep; frozen artifact on our controlled CDN — no migration needed |
| `container-security-provider` | 1.20.0 | 🔒 Always keep; frozen artifact on our controlled CDN — no migration needed |

### Investigate before acting

| Dependency | Issue |
|---|---|
| `cf-metrics-exporter` | No public GitHub repo found; verify provenance before automating |
| `contrast-security` | No public release API; check if Maven or alternate source available |
| `luna-security-provider` | Proprietary Thales HSM client; may require private hosting |

### Requires manual update only (commercial / no public API)

| Dependency | Reason |
|---|---|
| `jrebel` | Commercial Perforce product, no public version API |
| `sealights-agent` | Commercial product, proprietary CDN |
| `luna-security-provider` | Proprietary HSM client, not publicly redistributable |

### Remove from manifest

| Dependency | Version | Reason |
|---|---|---|
| `java-memory-assistant` | 0.5.0 | Archived by SAP Sep 2023 |
| `java-memory-assistant-cleanup` | 0.1.0 | Archived by SAP Sep 2023 |
| `auto-reconfiguration` | 2.12.0 | Spring Cloud Connectors deprecated 2019 |
| `spring-boot-cli` | 2.7.18 | Spring Boot 2.7.x EOL Jun 2023 |
| `metric-writer` | 3.5.0 | PCF Metrics Forwarder discontinued |

---

## Section 6 — Version Updates Required

The following are already on our S3 or being added, but the manifest version lags
significantly behind upstream.

| Dependency | Manifest Version | Latest | Gap | Action |
|---|---|---|---|---|
| `datadog-javaagent` | 1.42.1 | 1.60.3 | 18 minor versions | Update when adding to pipeline |
| `open-telemetry-javaagent` | 2.22.0 | 2.26.1 | 4 minor versions | Update when adding to pipeline |
| `splunk-otel-javaagent` | 2.22.0 | 2.26.1 | 4 minor versions | Update when adding to pipeline |
| `azure-application-insights` | 3.6.2 | 3.7.8 | 1 minor version | Update when adding to pipeline |
| `elastic-apm-agent` | 1.52.0 | 1.55.4 | 3 minor versions | Update when adding to pipeline |
| `newrelic` | 8.15.0 | 9.1.0 | 1 major version | Decision needed on 8.x → 9.x |
| `java-cfenv` | 3.5.0 | 4.0.0 | 1 major version | Decision needed on 3.x + 4.x tracking |
| `groovy` | 4.0.29 | 4.0.31 | 2 patch versions | Update when adding to pipeline |
| `tomcat` 9.x | 9.0.113 | 9.0.116 | 3 patch versions | Update if 9.x line is kept |

---

## Section 7 — Dependency Package Sizes

Sizes are the compressed download size as served (tgz/zip/jar). The offline buildpack
bundles **all** entries below — this is the source of the ~1.2 GB offline package.

> Sizes fetched 2026-03-31 via HTTP `Content-Length`. Sizes marked `~` are approximate
> (redirected or chunked responses). Sizes marked `N/A` could not be determined.

### JREs / JDKs — largest contributors

| Dependency | Version | Size | Host |
|---|---|---|---|
| `openjdk` | 8.0.482 | 40.2 MB | `buildpacks.cloudfoundry.org` ✅ |
| `openjdk` | 11.0.30 | 52.3 MB | `buildpacks.cloudfoundry.org` ✅ |
| `openjdk` | 17.0.18 | 55.9 MB | `buildpacks.cloudfoundry.org` ✅ |
| `openjdk` | 21.0.10 | 62.8 MB | `buildpacks.cloudfoundry.org` ✅ |
| `openjdk` | 25.0.2 | 79.8 MB | `buildpacks.cloudfoundry.org` ✅ |
| `zulu` | 8.0.482 | 40.5 MB | `buildpacks.cloudfoundry.org` ✅ |
| `zulu` | 11.0.30 | 41.2 MB | `buildpacks.cloudfoundry.org` ✅ |
| `zulu` | 17.0.18 | 47.1 MB | `buildpacks.cloudfoundry.org` ✅ |
| `sapmachine` | 17.0.18 | 47.1 MB | `buildpacks.cloudfoundry.org` ✅ |
| `sapmachine` | 21.0.10 | 52.3 MB | `buildpacks.cloudfoundry.org` ✅ |
| `sapmachine` | 25.0.2 | 49.4 MB | `buildpacks.cloudfoundry.org` ✅ |
| **JRE/JDK subtotal** | | **~618 MB** | |

### Profilers — second largest contributors

| Dependency | Version | Size | Host |
|---|---|---|---|
| `your-kit-profiler` | 2025.9.191 | 131.2 MB | `buildpacks.cloudfoundry.org` ✅ |
| `jprofiler-profiler` | 15.0.4 | 113.1 MB | `buildpacks.cloudfoundry.org` ✅ |
| **Profiler subtotal** | | **~244 MB** | |

### APM / Tracing agents

| Dependency | Version | Size | Host |
|---|---|---|---|
| `azure-application-insights` | 3.6.2 | 45.1 MB | github.com ⬇️ |
| `sealights-agent` | 4.0.2570 | 50.5 MB | vendor CDN ⬇️ |
| `newrelic` | 8.15.0 | 35.4 MB | vendor CDN ⬇️ |
| `jrebel` | 2025.4.1 | 31.9 MB | vendor CDN ⬇️ |
| `groovy` | 4.0.29 | 28.9 MB | `java-buildpack.cloudfoundry.org` 🔄 |
| `splunk-otel-javaagent` | 2.22.0 | 25.4 MB | github.com ⬇️ |
| `open-telemetry-javaagent` | 2.22.0 | 22.8 MB | github.com ⬇️ |
| `datadog-javaagent` | 1.42.1 | 29.6 MB | Maven Central ⬇️ |
| `skywalking-agent` | 9.6.0 | 43.5 MB | `buildpacks.cloudfoundry.org` ✅ |
| `elastic-apm-agent` | 1.52.0 | 11.5 MB | Maven Central ⬇️ |
| `contrast-security` | 6.23.0 | 18.7 MB | vendor CDN ⬇️ |
| `google-stackdriver-profiler` | 0.4.0 | 5.9 MB | `storage.googleapis.com` ⬇️ |
| **APM/Tracing subtotal** | | **~349 MB** | |

### Application server / Runtime support

| Dependency | Version | Size | Host |
|---|---|---|---|
| `tomcat` | 9.0.113 | 12.4 MB | `java-buildpack.cloudfoundry.org` 🔄 |
| `tomcat` | 10.1.52 | 13.7 MB | `buildpacks.cloudfoundry.org` ✅ |
| `tomcat` | 11.0.20 | 13.7 MB | `buildpacks.cloudfoundry.org` ✅ |
| `spring-boot-cli` | 2.7.18 | 13.9 MB | `java-buildpack.cloudfoundry.org` 🔄 ❌ EOL |
| `luna-security-provider` | 7.4.0-226 | 14.8 MB | `java-buildpack.cloudfoundry.org` ⚫ proprietary |
| `jvmkill` | 1.17.0 | 3.8 MB | `java-buildpack.cloudfoundry.org` 🔄 |
| `tomcat-access-logging-support` | 3.4.0 | < 0.01 MB | `java-buildpack.cloudfoundry.org` ✅ no action |
| `tomcat-lifecycle-support` | 3.4.0 | < 0.01 MB | `java-buildpack.cloudfoundry.org` ✅ no action |
| `tomcat-logging-support` | 3.4.0 | < 0.01 MB | `java-buildpack.cloudfoundry.org` ✅ no action |
| **App server subtotal** | | **~72 MB** | |

### CF runtime libraries

| Dependency | Version | Size | Host |
|---|---|---|---|
| `container-security-provider` | 1.20.0 | 1.7 MB | `java-buildpack.cloudfoundry.org` 🔒 no action |
| `client-certificate-mapper` | 2.0.1 | < 0.01 MB | `java-buildpack.cloudfoundry.org` 🔄 |
| `java-cfenv` | 3.5.0 | 0.9 MB | `java-buildpack.cloudfoundry.org` 🔄 |
| `auto-reconfiguration` | 2.12.0 | 2.1 MB | `java-buildpack.cloudfoundry.org` ❌ remove |
| `metric-writer` | 3.5.0 | < 0.01 MB | `java-buildpack.cloudfoundry.org` ❌ remove |
| **CF libraries subtotal** | | **~5 MB** | |

### JDBC drivers / other small libs

| Dependency | Version | Size | Host |
|---|---|---|---|
| `postgresql-jdbc` | 42.7.8 | 1.1 MB | `java-buildpack.cloudfoundry.org` 🔄 |
| `mariadb-jdbc` | 3.5.7 | 0.7 MB | `java-buildpack.cloudfoundry.org` 🔄 |
| `jacoco` | 0.8.14 | 0.3 MB | `java-buildpack.cloudfoundry.org` 🔄 |
| `cf-metrics-exporter` | 0.7.1 | 0.2 MB | Maven Central ⬇️ |
| `memory-calculator` | 4.1.0 | 0.8 MB | github.com 🔒 |
| `memory-calculator` | 4.2.0 | 0.8 MB | `java-buildpack.cloudfoundry.org` 🔒 no action |
| `java-memory-assistant` | 0.5.0 | 0.1 MB | github.com ❌ remove |
| `java-memory-assistant-cleanup` | 0.1.0 | 2.1 MB | github.com ❌ remove |
| **Small libs subtotal** | | **~6 MB** | |

---

### Total offline package size

| Category | Size |
|---|---|
| JREs / JDKs (11 entries) | ~618 MB |
| Profilers (2 entries) | ~244 MB |
| APM / Tracing (12 entries) | ~349 MB |
| App server / Runtime (9 entries) | ~72 MB |
| CF runtime libraries (5 entries) | ~5 MB |
| JDBC / small libs (8 entries) | ~6 MB |
| **Total (47 entries)** | **~1,294 MB** |

> This matches the reported ~1.2 GB offline buildpack size.

### Size impact of recommended removals

Removing the 5 EOL/deprecated dependencies from Section 4 would save:

| Dependency | Size | Saving |
|---|---|---|
| `java-memory-assistant` | 0.1 MB | small |
| `java-memory-assistant-cleanup` | 2.1 MB | small |
| `auto-reconfiguration` | 2.1 MB | small |
| `spring-boot-cli` | 13.9 MB | moderate |
| `metric-writer` | < 0.01 MB | negligible |
| **Total saving** | **~18 MB** | **~1.4% reduction** |

> The offline package size is dominated by JREs (~48%), profilers (~19%), and APM agents (~27%).
> Meaningful size reduction would require either removing JRE versions (e.g. dropping openjdk 8)
> or removing large APM agents (e.g. YourKit at 131 MB, JProfiler at 113 MB, SeaLights at 51 MB).

---

**Document maintained by:** buildpacks-ci team  
**Last updated:** 2026-03-31  
**Next review:** After Phase 1 migration complete
