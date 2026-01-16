# Remove cflinuxfs3 stack from CI infrastructure

## Motivation

The cflinuxfs3 stack (Ubuntu 18.04 based) has been superseded by cflinuxfs4 (Ubuntu 22.04). The cf-deployment project now ships exclusively with cflinuxfs4, and all buildpack pipelines have migrated to cflinuxfs4. This PR completes the cleanup by removing all cflinuxfs3-specific code and configurations from the buildpacks-ci repository.

## Changes

### Configuration Updates

**`pipelines/cf-release/cf-release-config.yml`**
- Changed `default_stacks` from `['cflinuxfs3']` to `['cflinuxfs4']`
- Impact: All cf-release pipeline builds now use cflinuxfs4 as the default stack

**`pipelines/dependency-builds/config.yml`**
- Removed `skip_lines_cflinuxfs3: [ '22.X.X' ]` for Node.js dependency
- Rationale: This configuration was only needed when cflinuxfs3 was still supported; Node 22 requires newer dependencies only available in cflinuxfs4

### Task Updates

**`tasks/update-libbuildpack/run.sh`**
- Changed default `CF_STACK` from `cflinuxfs3` to `cflinuxfs4`
- Impact: Unit tests now run against cflinuxfs4 by default

**`tasks/update-buildpack-dependency/run.rb`**
- Removed PHP cflinuxfs3.json special case handling (lines 55-56)
- Removed cflinuxfs3 stack name normalization logic (line 78)
- Removed `skip_lines_cflinuxfs3` version filtering (lines 92-94)
- Rationale: These were edge cases for cflinuxfs3-specific dependency builds

**`tasks/repackage-dependency/task.yml`**
- Updated Docker image from `cloudfoundry/cflinuxfs3` to `cloudfoundry/cflinuxfs4`
- Impact: Metadata repackaging tasks now run in cflinuxfs4 container

**`tasks/cf/redeploy/task.sh`**
- Removed `ADD_CFLINUXFS3_STACK` conditional block (lines 84-93)
- Rationale: This code uploaded cflinuxfs3 BOSH release and applied cflinuxfs3 operations files; no longer needed as cf-deployment includes only cflinuxfs4

**`tasks/cf/redeploy/task.yml`**
- Removed `ADD_CFLINUXFS3_STACK` parameter declaration
- Clean up unused parameter definition

**`tasks/generate-rootfs-release-notes/run.rb`**
- Removed cflinuxfs3 CVE feed URL
- Impact: Release notes generation now only processes cflinuxfs4 CVEs

**`lib/rootfs-cve-feed.rb`**
- Removed cflinuxfs3 stack handling from CVE feed processing
- Impact: CVE tracking now only applies to cflinuxfs4

### Deleted Folders

**`tasks/build-binary-new/`**
- Entire folder deleted (15 files, ~1600 lines)
- Rationale: This task used the `cloudfoundry/cflinuxfs3` Docker image to build binaries. Not referenced in any active pipeline. Superseded by `tasks/build-binary-new-cflinuxfs4/`

**`tasks/check-for-new-rootfs-cves/`**
- Entire folder deleted (2 files)
- Rationale: Hardcoded to check cflinuxfs3 CVEs from Ubuntu 18.04. Not referenced in any pipeline. Superseded by `tasks/check-for-new-rootfs-cves-cflinuxfs4/`

### Deleted Operations Files

**`tasks/cf/redeploy/operations/add-cflinuxfs3-to-current.yml`**
- BOSH operations file that added cflinuxfs3 stack alongside cflinuxfs4
- No longer needed as environments only use cflinuxfs4

**`tasks/cf/redeploy/operations/cflinuxfs3-rootfs-certs.yml`**
- Configured trusted certificates for cflinuxfs3 rootfs
- No longer needed

**`deployments/operations/cflinuxfs3.yml`**
- Previously deleted deployment configuration

**`deployments/operations/cflinuxfs3-rootfs-certs-as-list.yml`**
- Previously deleted certificate configuration

**`deployments/operations/substitute-with-cflinuxfs4-trusted-certs.yml`**
- Migration operations file that removed cflinuxfs3 and added cflinuxfs4
- Rationale: Obsolete since cf-deployment now ships with only cflinuxfs4 by default (verified in cf-deployment v54.2.0)

### Deleted Docker Assets

**`.github/workflows/build-cflinuxfs3-dev-image.yml`**
- GitHub Actions workflow that built cflinuxfs3-dev Docker image
- Rationale: References deleted `dockerfiles/cflinuxfs3-dev.Dockerfile`; no equivalent cflinuxfs4-dev workflow exists

**`dockerfiles/cflinuxfs3-dev.Dockerfile`**
- Previously deleted in earlier commit

## Testing

- All deleted tasks verified as unused via pipeline grep searches
- All buildpack values files already configured for cflinuxfs4 only
- cf-deployment repository confirmed to ship with cflinuxfs4 as default stack

## Related Work

This PR builds on previous cflinuxfs3 removal work and completes the cleanup across:
- CI pipeline configurations
- Task definitions and scripts
- BOSH operations files
- Docker image builds
- CVE tracking infrastructure
