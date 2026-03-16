# dependency-builds pipeline

This pipeline monitors upstream sources for new dependency versions, builds stack-specific
or stack-agnostic binaries, and opens pull requests against the affected buildpacks to update
their `manifest.yml`.

The pipeline is defined in `pipeline.yml` (ytt template) and driven entirely by `config.yml`
(ytt data-values). Rendering and deploying is done via `./bin/update-pipelines -p dependency-builds`.

---

## config.yml reference

### `buildpacks`

Optional per-buildpack overrides. Currently only used to set a non-default Git branch for
a buildpack repository.

```yaml
buildpacks:
  java:
    branch: feature/go-migration
```

If a buildpack is not listed here, the pipeline defaults to `master`.

---

### `build_stacks`

The list of Linux stacks for which native binaries are built.

```yaml
build_stacks: [ 'cflinuxfs4', 'cflinuxfs5' ]
```

Every dependency is built for **all stacks** in this list by default unless `any_stack: true`
is set (one build shared across all stacks) or `skip_lines` excludes specific version lines
from a stack.

Adding a new stack here is sufficient to pick it up across all dependencies — no per-dependency
changes are needed unless a dependency needs to explicitly skip that stack (see `skip_lines`).

---

### `windows_stacks`

Stacks treated as Windows targets. Only used by the `hwc` dependency, which overrides all
other stack logic and builds exclusively for these stacks.

```yaml
windows_stacks: [ 'windows' ]
```

---

### `dependencies`

The main map of all dependencies the pipeline manages. Each entry supports the following fields:

---

#### `buildpacks` *(required)*

Which buildpacks consume this dependency, and which version lines to track per buildpack.
A dependency can be consumed by multiple buildpacks, each with its own set of version lines.

```yaml
buildpacks:
  nodejs:
    lines:
      - line: 20.X.X
        deprecation_date: 2026-04-30
        link: https://github.com/nodejs/Release
      - line: 22.X.X
        deprecation_date: 2027-04-30
        link: https://github.com/nodejs/Release
    removal_strategy: keep_latest_released
  ruby:
    lines:
      - line: node-lts
```

**`line`** — version line pattern. Supported formats:
- `X.X.X` — patch-level tracking (e.g. `3.2.X`)
- `X.X` — minor-level tracking (e.g. `8.X.X`)
- `latest` — always track the single latest version
- named lines — e.g. `node-lts`

**`deprecation_date`** — when this version line reaches end of life. Used to open tracker
stories warning that the line is approaching EOL. Set to `""` if unknown or not applicable.

**`link`** — URL to the upstream EOL policy page. Included in deprecation notices.

**`match`** — optional regex used to filter versions within a line. Used by PHP where the
version filter alone is not precise enough.

```yaml
- line: 8.1.X
  match: 8.1.\d+
```

**`removal_strategy`** — how old versions of this dependency are pruned from the buildpack
manifest when a new version is added. Set per buildpack, since different buildpacks may have
different retention policies for the same dependency.

| Value | Behaviour |
|---|---|
| `remove_all` *(default)* | Remove all older versions in the same line |
| `keep_latest_released` | Keep one version from the latest released buildpack as a rollback safety net |
| `keep_all` | Never remove old versions |

---

#### `versions_to_keep`

How many versions of this dependency to retain in the buildpack manifest per stack entry.
Works in conjunction with `removal_strategy` — once the strategy decides which versions are
candidates for removal, `versions_to_keep` sets the maximum number to retain.

```yaml
versions_to_keep: 2   # keep the two most recent versions
versions_to_keep: 1   # keep only the latest version
```

---

#### `source_type`

The depwatcher resource type used to watch for new upstream versions. This maps directly to
the `type` field of the depwatcher Concourse resource. Defaults to the dependency name if omitted.

| Value | Used for |
|---|---|
| `github_releases` | Dependencies released via GitHub releases |
| `github_tags` | Dependencies versioned via Git tags |
| `rubygems` | RubyGems packages |
| `rubygems_cli` | RubyGems CLI tool |
| `npm` | npm packages |
| `pypi` | Python packages on PyPI |
| `node` | Node.js releases |
| `php` | PHP releases |
| `nginx` | nginx releases |
| `jruby` | JRuby releases |
| `appd_agent` | AppDynamics agent |
| `appdynamics` | AppDynamics Java agent |
| `liberica` | BellSoft Liberica JDK/JRE |
| `zulu` | Azul Zulu JDK/JRE |
| `skywalking` | Apache SkyWalking agent |
| `jprofiler` | JProfiler profiler |
| `yourkit` | YourKit profiler |
| `tomcat` | Apache Tomcat |

---

#### `source_params`

Extra parameters passed to the depwatcher resource for version discovery. Each entry is a
`key: value` string.

```yaml
source_params:
  - 'repo: cloudfoundry/hwc'
  - 'extension: .tar.gz'
  - 'fetch_source: true'
  - 'tag_regex: ^[0-9]+\.[0-9]+$'
  - 'glob: *jre-*_linux-x64_bin.tar.gz'
  - 'uri: https://archive.apache.org/dist/tomcat'
```

---

#### `any_stack`

When `true`, the dependency is compiled once and the resulting binary is compatible with all
stacks in `build_stacks`. The build runs on the cflinuxfs4 image and the artifact is tagged
`any-stack` rather than a specific stack name.

Use this for dependencies that are not OS-native — JVM-based tools, pre-built upstream
binaries, pure interpreted packages (pip, npm, rubygems), etc.

```yaml
any_stack: true   # one build, shared across all stacks
any_stack: false  # one build per stack in build_stacks (default)
```

When `false` or omitted, a separate native binary is compiled for each stack in `build_stacks`.

---

#### `skip_lines`

Prevents specific version lines from being built or written into the manifest for a given
stack. Use this when a version line is known to be incompatible with a particular stack OS.

```yaml
skip_lines:
  cflinuxfs4: [ '2.7.X', '3.0.X' ]
  cflinuxfs5: [ '2.7.X' ]
```

Version lines listed here are excluded from the build job for that stack and are not added
to the buildpack manifest for that stack. Lines not listed are unaffected.

A version line listed under `skip_lines` that is no longer present in the active `lines:`
list has no runtime effect but should be kept as documentation explaining why that line was
never supported on that stack.

---

#### `mixins`

Stack-specific OS packages that the built binary depends on at runtime. Written into the
manifest entry so the buildpack knows which system libraries to request.

```yaml
mixins:
  'io.buildpacks.stacks.bionic':
    - libargon2-0
    - libcurl4
    - libxml2
```

---

#### `monitored_deps`

Additional depwatcher sources that trigger a rebuild of this dependency when they publish a
new version. Used when a dependency bundles sub-dependencies that must be kept current.

```yaml
monitored_deps:
  - rserve
  - forecast
  - shiny
  - plumber
```

Each entry must have a corresponding `source-{name}-latest` depwatcher resource registered.

---

#### `third_party_hosted`

When `true`, the built binary is not uploaded to the buildpacks S3 bucket. The artifact URL
points to the upstream host instead. Only the build metadata (`.json`) is pushed to the
builds repository.

```yaml
third_party_hosted: true
```

---

#### `copy-stacks`

After a build, copy the artifact to additional stacks without rebuilding. Useful when a
binary built for one stack is compatible with another but needs a separate manifest entry.

```yaml
copy-stacks:
  - cflinuxfs5
```

---

### `skip_deprecation_check`

Dependencies listed here are excluded from the EOL date validation job. Add a dependency here
when it does not publish a formal EOL schedule or when its deprecation dates are redundant
(e.g. `dotnet-sdk` and `dotnet-aspnetcore` share the same schedule as `dotnet-runtime`).

```yaml
skip_deprecation_check:
  - bundler       # doesn't publish EOL schedule
  - dotnet-sdk    # same schedule as dotnet-runtime
  - nginx         # doesn't publish EOL schedule
```

---

## How to add a new stack (e.g. cflinuxfs6)

1. Add the stack to `build_stacks` in `config.yml`
2. Add a `build-binary-new-cflinuxfs6/` task directory mirroring `build-binary-new-cflinuxfs5/`
3. The Docker image resource and build jobs are generated automatically from `build_stacks` —
   no manual changes to `pipeline.yml` are needed
4. If a dependency is not yet validated on the new stack, add it to that dependency's
   `skip_lines` for the new stack until it is confirmed working

## How to add a new dependency

1. Add an entry under `dependencies:` in `config.yml` with at minimum:
   - `buildpacks` with at least one buildpack and version line
   - `versions_to_keep`
   - `any_stack: true` if the binary is not OS-native, omit otherwise
2. Add the dependency name to `skip_deprecation_check` if it has no formal EOL schedule
3. Run `./bin/update-pipelines -p dependency-builds` to apply

## How to retire a version line

Remove the `line` entry from the relevant buildpack under `dependencies` in `config.yml` and
run `./bin/update-pipelines -p dependency-builds`. The build and update jobs for that line
will disappear from the pipeline. The versions already in the buildpack manifests are not
automatically removed — that requires a separate manifest cleanup PR.
