# S3 Namespace Migration

Tools for migrating the `buildpacks.cloudfoundry.org` S3 bucket from a flat UUID layout to per-buildpack namespaced folders, as described in the [S3 Bucket Namespacing RFC](https://github.com/ramonskie/community/blob/main/toc/rfc/rfc-draft-buildpacks-s3-bucket-namespacing.md).

## Background

All BOSH release blobs are stored as flat UUIDs in the S3 bucket root:

```
s3://buildpacks.cloudfoundry.org/<uuid>
s3://buildpacks.cloudfoundry.org/<uuid>
...
```

After this migration, each blob will live under a folder matching its buildpack's `final_name`:

```
s3://buildpacks.cloudfoundry.org/ruby-buildpack/<uuid>
s3://buildpacks.cloudfoundry.org/nodejs-buildpack/<uuid>
...
```

Root-level copies are kept for a 30-day rollback grace period, then deleted manually with `cleanup-blobs.sh`. Blobs with no known owner are moved to `orphaned/` and deleted manually with `cleanup-orphans.sh`.

## Prerequisites

| Tool | Purpose |
|------|---------|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | S3 operations |
| Python 3.8+ | Migration plan generation and blob.yml parsing |
| [PyYAML](https://pypi.org/project/PyYAML/) | Parsing `config/blobs.yml` in verify script |

```bash
pip install pyyaml
```

AWS credentials must be configured with read/write access to `buildpacks.cloudfoundry.org`.

## Recommended Migration Workflow

### Step 0 — Check prerequisites

```bash
make check-prereqs
```

### Step 1 — Generate uuid-mapper output

The migration scripts read CSV files produced by the `uuid-mapper` tool. Run it once before doing anything else:

```bash
make uuid-mapper-output
# or manually:
cd ../uuid-mapper && python3 mapper.py --no-serve
```

This creates the following files in `../uuid-mapper/output/`:

| File | Contents |
|------|----------|
| `all_blob_history.csv` | Full git history of all blob UUIDs per repo |
| `uuid_mapping_current.csv` | Current (most-recent) UUID per blob name |
| `orphaned_blobs.csv` | UUIDs in S3 not found in any git repo |
| `blobs_by_release.csv` | Blob counts grouped by release |

### Step 2 — Review the migration plan

```bash
make plan                          # human-readable summary
make plan BUILDPACK=ruby-buildpack # single namespace only
make plan-csv > plan.csv           # machine-readable
make plan-json > plan.json         # JSON
```

The plan tool makes **no changes to S3** — it is safe to run at any time.

### Step 3 — Dry-run the migration

```bash
make migrate-dry-run
make migrate-dry-run BUILDPACK=ruby-buildpack  # single namespace
```

This prints the `aws s3 cp` commands that would be executed without running them.

### Step 4 — Run the migration

```bash
make migrate
make migrate BUILDPACK=ruby-buildpack  # single namespace (useful for testing)
```

Each blob is **copied** (not moved) from the bucket root to `<folder>/<uuid>`. Already-migrated blobs are skipped automatically. The original root-level blob is left intact for 30 days.

### Step 5 — Verify the migration

```bash
make verify                              # fast: checks existence and size
make verify-sha                          # slow: also downloads and sha256sums each blob
make verify BUILDPACK=ruby-buildpack     # single namespace
```

The verify script reads `config/blobs.yml` and `config/final.yml` from each local buildpack release repo and confirms every active UUID is present at its expected namespaced path in S3.

### Step 6 — Handle orphaned blobs

```bash
make orphans-dry-run   # preview which blobs will be moved
make orphans           # move orphaned blobs to orphaned/ (interactive confirmation)
```

After moving orphans, run `make cleanup-orphans` when you are ready to permanently delete them.

## Makefile Reference

```
make help              # show all targets
make check-prereqs     # verify tools are installed
make uuid-mapper-output # regenerate CSV input files
make plan              # text migration plan
make plan-csv          # CSV migration plan
make plan-json         # JSON migration plan
make migrate-dry-run   # dry-run blob copy
make migrate           # copy blobs to namespaced folders
make verify            # verify blob existence and size
make verify-sha        # verify blob checksums (slow)
make orphans-dry-run   # dry-run orphan move
make orphans           # move orphaned blobs to orphaned/
make cleanup-dry-run   # dry-run root-blob deletion
make cleanup           # delete root-level blobs after grace period
make cleanup-force     # delete root-level blobs, bypassing grace period
make cleanup-orphans-dry-run  # dry-run orphaned/ deletion
make cleanup-orphans   # permanently delete blobs from orphaned/
```

Override defaults:

```bash
make migrate BUCKET=my-test-bucket
make verify  RELEASES_DIR=/path/to/buildpacks-release
make plan    BUILDPACK=ruby-buildpack
```

## Script Reference

### `generate-migration-plan.py`

Reads `all_blob_history.csv` and prints a human-readable plan showing which UUIDs will be copied to which folder. Makes no S3 changes.

```
./generate-migration-plan.py [--input-dir DIR] [--output FILE] [--format text|csv|json] [--buildpack NAME]
```

### `migrate-blobs.sh`

Copies blobs from the S3 bucket root into per-buildpack namespaced folders.

```
./migrate-blobs.sh [--bucket BUCKET] [--input-dir DIR] [--dry-run] [--buildpack NAME] [--parallel N]
```

### `migrate-orphans.sh`

Moves orphaned blobs (not referenced in any git repo) from the bucket root to `orphaned/`.

```
./migrate-orphans.sh [--bucket BUCKET] [--input-dir DIR] [--dry-run]
```

### `verify-migration.sh`

Verifies all active blobs from `config/blobs.yml` exist at their namespaced S3 paths. Reads `folder_name` from `config/final.yml`.

```
./verify-migration.sh [--bucket BUCKET] [--releases-dir DIR] [--buildpack NAME] [--check-sha]
```

### `cleanup-blobs.sh`

Deletes original root-level flat UUID blobs after the grace period has elapsed. Reads `output.json` produced by `migrate-blobs.sh` (falls back to `all_blob_history.csv`). Verifies the namespaced copy exists in S3 before deleting each root blob.

```
./cleanup-blobs.sh [--bucket BUCKET] [--input-dir DIR] [--grace-days N] [--dry-run] [--force] [--buildpack NAME]
```

### `cleanup-orphans.sh`

Permanently deletes blobs from the `orphaned/` folder. Only deletes objects that exist under the `orphaned/` prefix — will not touch anything else.

```
./cleanup-orphans.sh [--bucket BUCKET] [--input-dir DIR] [--dry-run]
```

## Folder → Buildpack Mapping

| S3 Folder | BOSH Release Repo |
|-----------|-------------------|
| `binary-buildpack` | `binary-buildpack-release` |
| `dotnet-core-buildpack` | `dotnet-core-buildpack-release` |
| `go-buildpack` | `go-buildpack-release` |
| `hwc-buildpack` | `hwc-buildpack-release` |
| `java-buildpack` | `java-buildpack-release` |
| `java-offline-buildpack` | `java-offline-buildpack-release` |
| `nginx-buildpack` | `nginx-buildpack-release` |
| `nodejs-buildpack` | `nodejs-buildpack-release` |
| `php-buildpack` | `php-buildpack-release` |
| `python-buildpack` | `python-buildpack-release` |
| `r-buildpack` | `r-buildpack-release` |
| `ruby-buildpack` | `ruby-buildpack-release` |
| `staticfile-buildpack` | `staticfile-buildpack-release` |
| `cflinuxfs3` | `cflinuxfs3-release` |
| `cflinuxfs4` | `cflinuxfs4-release` |
