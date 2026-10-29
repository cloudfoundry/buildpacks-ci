# Migration Plan: Move PHP Extension Configuration from binary-builder to php-buildpack

## Motivation

binary-builder is a generic compilation tool. It should not own buildpack-specific
configuration like which PECL extension versions to compile. Today, the PHP extension
version matrix (40+ extensions across 5 PHP minor versions) is embedded in
binary-builder via `go:embed`, meaning:

1. **Bumping a PECL extension version requires a binary-builder commit** and recompilation —
   the php-buildpack team cannot manage extension versions independently.
2. **No automation is possible** without coupling the depwatcher/pipeline to binary-builder
   internals. Other deps (node, python, ruby) are fully automated; PHP extensions are
   entirely manual.
3. **Visibility is poor** — extension version configs are buried in a build tool, not in
   the buildpack they affect. Customers and operators cannot inspect the buildpack repo
   to understand which extension versions ship with which PHP version.

## Current Architecture

```
binary-builder repo
  internal/php/assets/
    php8-base-extensions.yml          ← extension versions defined here
    php84-extensions-patch.yml        ← per-PHP-version overrides
    php85-extensions-patch.yml
  internal/php/extensions.go          ← go:embed compiles YAML into binary

CI pipeline (buildpacks-ci)
  depwatcher detects new PHP core version
    → build.sh compiles binary-builder from source
    → binary-builder build --source-file source/data.json
    → internally: php.Load(major, minor) reads embedded YAML
    → compiles all extensions into PHP tarball
    → uploads to S3
    → opens PR on php-buildpack to update manifest.yml

Manual workflow (developer-run)
  scripts/php-modules/bump-versions.rb  ← scrapes PECL RSS, updates YAML in binary-builder
  scripts/php-modules/update-hashes.rb  ← recomputes MD5 for bumped extensions
```

## Target Architecture

```
php-buildpack repo
  config/extensions/
    php8-base-extensions.yml          ← extension versions live here now
    php84-extensions-patch.yml
    php85-extensions-patch.yml

CI pipeline (buildpacks-ci)
  depwatcher detects new PHP core version
    → build.sh compiles binary-builder from source
    → build.sh passes extension YAML to binary-builder via --extensions-dir
    → binary-builder build --source-file source/data.json --extensions-dir php-buildpack/config/extensions
    → php.Load() reads from filesystem instead of (or in addition to) go:embed
    → compiles all extensions into PHP tarball
    → uploads to S3, opens PR on php-buildpack

  NEW: PECL extension watcher (weekly cron or depwatcher)
    → detects outdated extensions
    → opens PRs directly on php-buildpack to bump extension YAML files

binary-builder repo
  internal/php/extensions.go          ← Load() accepts external dir; go:embed is fallback only
  internal/php/assets/                ← kept as defaults for local dev/testing, not authoritative
```

## Migration Phases

### Phase 1: binary-builder — Accept external extension config (backward-compatible)

**Goal:** binary-builder can load extension YAML from a filesystem path, falling back to
embedded defaults when no path is provided. Zero breaking changes.

**Changes in binary-builder:**

1. **Add `--extensions-dir` CLI flag** (`cmd/binary-builder/main.go`)

   New optional flag on the `build` subcommand:
   ```
   --extensions-dir string    Directory containing PHP extension YAML files (default: use embedded)
   ```

2. **Add `LoadFromDir(dir, phpMajor, phpMinor)` function** (`internal/php/extensions.go`)

   New public function that reads base + patch files from a filesystem directory using
   the same naming convention (`php8-base-extensions.yml`, `php84-extensions-patch.yml`).
   The existing `Load()` becomes a thin wrapper that delegates to the embedded FS.

   ```go
   // LoadFromDir loads extension config from the given directory.
   // File naming convention is identical to the embedded assets.
   func LoadFromDir(dir, phpMajor, phpMinor string) (*ExtensionSet, error) { ... }

   // Load loads extension config from the embedded assets (backward compat).
   func Load(phpMajor, phpMinor string) (*ExtensionSet, error) { ... }
   ```

3. **Thread `extensionsDir` through the PHP recipe** (`internal/recipe/php.go`)

   The `PHPRecipe` struct gets an `ExtensionsDir string` field. If set, `Build()` calls
   `php.LoadFromDir()`; otherwise it calls `php.Load()`. The field is set from the CLI
   flag via the registry.

4. **Tests:**
   - Unit test for `LoadFromDir()` with temp directory containing test YAML files
   - Integration test confirming embedded fallback still works when `--extensions-dir` is not set
   - Run full test suite (`go test -race ./...`)

**Acceptance criteria:** `binary-builder build --stack cflinuxfs4` works identically with
and without `--extensions-dir`. Existing CI pipeline is unaffected.

---

### Phase 2: php-buildpack — Add extension config files

**Goal:** The php-buildpack repo contains the authoritative extension YAML files.

**Changes in php-buildpack:**

1. **Copy extension YAML files** from `binary-builder/internal/php/assets/` to
   `php-buildpack/config/extensions/`:
   ```
   config/extensions/
     php8-base-extensions.yml
     php81-extensions-patch.yml
     php82-extensions-patch.yml
     php83-extensions-patch.yml
     php84-extensions-patch.yml
     php85-extensions-patch.yml
   ```

2. **Add `.buildpack-extensions` marker or README** documenting the file format and
   naming convention so maintainers know how to add new PHP versions.

3. **Move `scripts/php-modules/` from buildpacks-ci to php-buildpack** (or create
   equivalent tooling):
   ```
   scripts/
     bump-extension-versions.sh    ← wraps the PECL scraper
     update-extension-hashes.sh    ← recomputes MD5 after bumps
   ```

   These scripts operate on `config/extensions/` in the same repo — no cross-repo
   dependency on binary-builder.

**Acceptance criteria:** Extension YAML files in php-buildpack are byte-identical to
those in binary-builder. Scripts can be run locally against the php-buildpack repo.

---

### Phase 3: buildpacks-ci — Update pipeline to pass extension config

**Goal:** The CI pipeline passes the php-buildpack's extension config to binary-builder
during PHP builds.

**Changes in buildpacks-ci:**

1. **Update `build-php-*` jobs** in `pipelines/dependency-builds/pipeline.yml`:

   Add `php-buildpack` as a git input to the build job:
   ```yaml
   - get: php-buildpack
     resource: php-buildpack-git
   ```

2. **Update `tasks/build-binary/build.sh`** to pass `--extensions-dir` for PHP builds:

   ```bash
   EXTRA_ARGS=()
   if [[ "${DEP_NAME}" == "php" && -d "php-buildpack/config/extensions" ]]; then
     EXTRA_ARGS=(--extensions-dir "php-buildpack/config/extensions")
   fi

   binary-builder build \
     --stack "${BUILD_STACK}" \
     --source-file source/data.json \
     --stacks-dir binary-builder/stacks \
     --output-file "${SUMMARY_FILE}" \
     "${EXTRA_ARGS[@]}"
   ```

3. **Update `scripts/php-modules/update.rb`** to point at php-buildpack instead of
   binary-builder:
   ```ruby
   PHP_BUILDPACK_DIR = ENV.fetch('PHP_BUILDPACK_DIR', File.join(__dir__, '..', '..', '..', 'php-buildpack'))
   EXTENSION_YAML_DIR = File.join(PHP_BUILDPACK_DIR, 'config', 'extensions')
   ```

**Acceptance criteria:** PHP builds use extension configs from php-buildpack. Changing
an extension version in php-buildpack (without touching binary-builder) triggers a
correct PHP rebuild.

**Rollback procedure:**

1. Revert the `build.sh`, `build.yml`, and `pipeline.yml` changes in a commit to
   `buildpacks-ci`.
2. **Important:** Pipeline YAML changes in `pipelines/dependency-builds/pipeline.yml`
   do NOT take effect until the pipeline is regenerated. After the revert commit
   lands on master, run `./bin/update-pipelines` (or the equivalent `fly set-pipeline`
   command) to apply the change to the running Concourse pipeline. A revert commit
   alone will NOT revert the running pipeline — this is a known operational footgun.
3. The next PHP build will use binary-builder's embedded extension defaults (the
   `build.sh` fallback path handles this gracefully — when the `php-buildpack`
   input is absent or lacks `config/extensions/`, no `--extensions-dir` flag is
   passed and binary-builder falls back to its compiled-in YAML).

---

### Phase 4: Automation — PECL extension version monitoring

**Goal:** Outdated extensions are detected automatically, with either notifications or
automated PRs.

**Option A: Notification-only (recommended first step)**

Add a weekly Concourse job in the php-buildpack pipeline that:
1. Clones `php-buildpack`
2. Runs the `bump-extension-versions.sh` script in dry-run mode
3. Compares current vs. available versions
4. If any extension is outdated:
   - Creates a GitHub issue on `cloudfoundry/php-buildpack` listing the outdated extensions
   - Or posts to a Slack channel

**Option B: Automated PRs (future)**

Add a `pecl` source type to the depwatcher:
1. New watcher (`dockerfiles/depwatcher-go/pkg/watchers/pecl.go`) that monitors
   `pecl.php.net/feeds/pkg_{name}.rss`
2. Register tracked extensions in `config.yml`:
   ```yaml
   php-ext-mongodb:
     source_type: pecl
     source:
       pecl_name: mongodb
     buildpacks:
       php:
         lines:
           - line: 2.x
             match: 2\.\d+\.\d+
           - line: 1.x
             match: 1\.\d+\.\d+
   ```
3. Pipeline jobs that, on new version detection, update the extension YAML in
   php-buildpack and open a PR

**Caveat:** Not all PECL version bumps are compatible with all PHP versions. The
automated PR should be marked as needing human review (draft PR), or the pipeline
should run a test build to verify compilation succeeds before marking the PR ready.

---

### Phase 5: Cleanup — Remove embedded config from binary-builder

**Goal:** binary-builder no longer ships extension configuration. The embedded assets
become test fixtures only.

**Changes in binary-builder:**

1. **Move `internal/php/assets/` to `internal/php/testdata/`** — files are only used
   by unit tests and local development, not by production builds.

2. **Update `Load()` to require an explicit directory** — remove the embedded fallback
   from production code paths. The `--extensions-dir` flag becomes required for PHP
   builds (the `build.sh` script always passes it).

   ```go
   // Load is kept for backward compat / tests; delegates to LoadFromDir with embedded testdata.
   func Load(phpMajor, phpMinor string) (*ExtensionSet, error) {
       return LoadFromDir("internal/php/testdata", phpMajor, phpMinor)
   }
   ```

3. **Update AGENTS.md / README** to document that extension config lives in the
   php-buildpack repo.

4. **Remove `scripts/php-modules/` from buildpacks-ci** (already moved to php-buildpack
   in Phase 2).

**Acceptance criteria:** `binary-builder build` without `--extensions-dir` fails for PHP
builds with a clear error message directing the user to provide extension config.

---

## Rollback Strategy

Each phase is independently deployable and backward-compatible:

- **Phase 1** adds a new optional flag; no existing behavior changes.
- **Phase 2** adds files to php-buildpack; no existing behavior changes.
- **Phase 3** starts using the new flag; revert `build.sh` and `pipeline.yml` to remove
  `--extensions-dir` to fall back to embedded config. **Important:** pipeline YAML
  changes require running `./bin/update-pipelines` after the revert commit — a git
  revert alone does NOT update the running Concourse pipeline.
- **Phase 4** is additive automation; disable/remove the cron job to revert.
- **Phase 5** is the only breaking change — it removes the embedded fallback. If issues
  arise, revert the binary-builder commit to restore embedded assets.

Phases 1-4 can be merged independently. Phase 5 should only be done after Phase 3 has
been running successfully in production for at least one full PHP release cycle.

## Cross-Repository Dependencies

| Phase | binary-builder | php-buildpack | buildpacks-ci |
|-------|---------------|---------------|---------------|
| 1     | **Changes**   | —             | —             |
| 2     | —             | **Changes**   | —             |
| 3     | —             | —             | **Changes**   |
| 4     | —             | —             | **Changes**   |
| 5     | **Changes**   | —             | **Changes**   |

No phase requires simultaneous merges across repos. Each phase's changes are
self-contained within a single repository.

## Estimated Effort

| Phase | Effort | Risk | Priority | Status |
|-------|--------|------|----------|--------|
| 1     | Small (1-2 days)  | Low  | High — unblocks everything else | **In progress** — [PR #126](https://github.com/cloudfoundry/binary-builder/pull/126) |
| 2     | Small (half day)  | Low  | High — moves the config | Not started |
| 3     | Medium (1-2 days) | Medium — needs pipeline testing | High — enables the new flow | Not started |
| 4     | Medium (2-3 days) | Low  | Medium — nice-to-have automation | **In progress** — Option A (GitHub Actions weekly check) |
| 5     | Small (half day)  | Medium — breaking change | Low — cleanup, do last | Not started |

Total: ~1-2 weeks of focused work across all phases.
