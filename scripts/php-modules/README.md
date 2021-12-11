# PHP Module Helper Scripts

Updating PHP modules entails two main steps: determining which modules to update, then updating hashes for bumped modules. The following scripts help with each step. They operate on the following module configuration files:

- `tasks/build-binary-new/php7-base-extensions.yml`
- `tasks/build-binary-new/php74-extensions-patch.yml` (`additions` array)
- `tasks/build-binary-new/php8-base-extensions.yml`

## Bump Module Versions

Determining which modules to bump cannot be fully automated because some human analysis is required to determine whether the bumped version would support a given version of PHP. However, running the following script can fetch new versions of all modules, then bump them, allowing the developer running the script to then analyze the diff and determine if any changes should be manually reverted/adjusted.

To bump versions, run:

```bash
./scripts/php-modules/bump-versions.sh
```

This will attempt to bump all modules to their latest versions and clear each bumped module's `md5` field to signal that it should be recomputed (see next section).

> **Note:** In some cases, a new module version will support a version of PHP that it didn't previously support. In this case, the module would need to be added manually to the appropriate extensions YAML file (leaving the `md5` field blank).

## Update Module Hashes

This script will recompute hashes for all PHP modules whose `md5` field is blank. This script is useful for computing hashes for newly-added modules or for modules updated using the `bump-versions.sh` script described previously.

To update hashes, run:

```bash
./scripts/php-modules/update-hashes.sh
```

## Important Notes

- These scripts assume that you have cloned [binary-builder](https://github.com/cloudfoundry/binary-builder) into a `binary-builder` directory next to this `buildpacks-ci` repo. It also assumes you have `bundler` installed.

- If you run into rate limits for GitHub, try setting the `GITHUB_TOKEN` environment variable before running the scripts (the token only needs the `public_repo` scope). Authenticated requests have a much higher limit.

- Modules with empty or `nil` versions will not be processed.
