# PHP Module Helper Scripts

Updating PHP modules entails two main steps: determining which modules to update, then updating hashes for bumped modules. The following scripts help with each step.

They operate on extension config files in the [binary-builder](https://github.com/cloudfoundry/binary-builder) repo:

- `internal/php/assets/php8-base-extensions.yml`
- `internal/php/assets/php81-extensions-patch.yml` (`additions` array)

## Bump Module Versions

Determining which modules to bump cannot be fully automated because some human analysis is required to determine whether the bumped version would support a given version of PHP. However, running the following script can fetch new versions of all modules, then bump them, allowing the developer running the script to then analyze the diff and determine if any changes should be manually reverted/adjusted.

To bump versions, run:

```bash
./scripts/php-modules/bump-versions.sh
```

This will attempt to bump all modules to their latest versions and clear each bumped module's `md5` field to signal that it should be recomputed (see next section).

### Dry-run mode

To check which extensions are outdated **without modifying any files**, use the `--dry-run` flag:

```bash
bundle exec ruby scripts/php-modules/bump-versions.rb --dry-run
```

For machine-readable output (used by the automated GitHub Actions check), add `--format=json`:

```bash
bundle exec ruby scripts/php-modules/bump-versions.rb --dry-run --format=json
```

The JSON output includes:
- `outdated` — array of `{name, klass, current, latest}` objects
- `up_to_date_count` — number of extensions already at their latest version
- `error_count` / `errors` — any extensions that could not be checked

> **Note:** In some cases, a new module version will support a version of PHP that it didn't previously support. In this case, the module would need to be added manually to the appropriate extensions YAML file (leaving the `md5` field blank).

## Update Module Hashes

This script will recompute hashes for all PHP modules whose `md5` field is blank. This script is useful for computing hashes for newly-added modules or for modules updated using the `bump-versions.sh` script described previously.

To update hashes, run:

```bash
./scripts/php-modules/update-hashes.sh
```

## Important Notes

- These scripts need access to the extension YAML files. You can point them at the YAML directory in two ways:

  **Option 1 (preferred):** Set `EXTENSIONS_DIR` to point directly at the directory containing the YAML files:

  ```bash
  # From php-buildpack (authoritative source after Phase 2):
  EXTENSIONS_DIR=/path/to/php-buildpack/config/extensions ./scripts/php-modules/bump-versions.sh

  # From binary-builder testdata (for local dev):
  EXTENSIONS_DIR=/path/to/binary-builder/internal/php/testdata ./scripts/php-modules/bump-versions.sh
  ```

  **Option 2 (legacy):** Set `BINARY_BUILDER_DIR` — the scripts will look for YAML files in `BINARY_BUILDER_DIR/internal/php/assets`:

  ```bash
  BINARY_BUILDER_DIR=/path/to/binary-builder ./scripts/php-modules/bump-versions.sh
  ```

  If neither is set, the scripts default to looking for `../binary-builder` as a sibling directory.

  The scripts also assume you have `bundler` installed.

- If you run into rate limits for GitHub, try setting the `GITHUB_TOKEN` environment variable before running the scripts (the token only needs the `public_repo` scope). Authenticated requests have a much higher limit.

- Modules with empty or `nil` versions will not be processed.

## Pre-buildpack-release task

Except for Out-of-band releases, before every release of the [PHP buildpack](https://github.com/cloudfoundry/php-buildpack),
make sure modules are bumped to latest compatible versions and built into the
buildpack dependencies.

Run the helper scripts mentioned above which can bump modules (mostly)
automatically. These scripts bump as many modules as they can, but the results
should still be checked manually before committing.
Some must be bumped manually, and it's still important to check if a module
supports a new version of PHP which it didn't previously support (in which case
it should be added manually).

If the module release is compatible with all of 8.0, 8.1...8.N, update the
`php8-base-extensions.yml` file. Otherwise, update the respective patch file(s)
(e.g. `php8.N-extensions-patch.yml`)

*[Cassandra]* If you're updating cassandra modules (including
datastax/cpp-driver) it's advisable to do so in individual commits, then
rebuild appropriate php versions, so integration tests can run in CI with only
cassandra changes. This will help isolate the php cassandra module change(s) if
the changes cause problems.

You can use the following task-list to help this operation:

* [ ] Make sure any newly available versions of PHP are pulled into the buildpack
* [ ] Check each PHP module for updates and update extension configs
* [ ] Rebuild PHP versions if any module updates ([pipeline](https://buildpacks.ci.cf-app.com/teams/main/pipelines/dependency-builds?group=php))
* [ ] Make sure newly built dependency is merged into the buildpack

## Automated Weekly Check

A GitHub Actions workflow in [binary-builder](https://github.com/cloudfoundry/binary-builder)
runs weekly (Monday 08:00 UTC) and uses `bump-versions.rb --dry-run --format=json` to
detect outdated PHP extensions. When outdated extensions are found, the workflow
creates or updates a GitHub issue on the binary-builder repo with a summary table.

The workflow can also be triggered manually from the Actions tab. See
`.github/workflows/check-php-extensions.yml` in the binary-builder repo.
