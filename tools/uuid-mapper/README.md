# UUID Blob Mapper Tool

**Maps BOSH blob UUIDs to human-readable filenames by analyzing complete git history**

## Problem

The S3 bucket `s3://buildpacks.cloudfoundry.org/` contains **4,351 UUID-named files** like:
```
29a57fe6-b667-4261-6725-124846b7bb47
51030935-2021-40c6-6c74-e14b79af830f
```

These are BOSH blobs, but without context:
- ❌ Can't identify what they are
- ❌ Can't tell if they're still needed
- ❌ Can't clean up safely
- ❌ Can't audit or manage the bucket

## Solution

This tool analyzes **two sources** of BOSH blob references across all buildpack release repositories:

1. **`config/blobs.yml`** - Source dependency blobs (git history analysis)
2. **`.final_builds/packages/`** - Compiled package blobs (compiled for each stack)
3. **`.final_builds/jobs/`** - BOSH job template blobs

This creates a comprehensive UUID → filename mapping database.

### Key Features

✅ **Complete Coverage** - Scans config/blobs.yml, .final_builds/packages, and .final_builds/jobs  
✅ **Historical Analysis** - Analyzes every commit, not just current state  
✅ **Release Mapping** - Shows which BOSH releases use each UUID  
✅ **Multi-Repository** - Scans 13+ buildpack release repos  
✅ **Orphan Detection** - Identifies blobs in S3 but not in any repository  
✅ **S3 Caching** - Caches S3 listing for 24h (faster reruns)  
✅ **Parallel Processing** - Fast execution with concurrent workers  
✅ **Interactive Web UI** - Auto-starts HTTP server with searchable interface  
✅ **Multiple Outputs** - CSV, JSON, and HTML reports  

## Quick Start

### Prerequisites

```bash
# Python 3.8+
python3 --version

# AWS CLI configured
aws s3 ls s3://buildpacks.cloudfoundry.org/ | head -1

# Git
git --version
```

### Installation

```bash
cd tools/uuid-mapper
pip install -r requirements.txt
```

### Run

```bash
# Default: Analyze + start web viewer (recommended)
./mapper.py

# The script will:
# 1. Analyze all buildpack release repos (~5-10 min)
# 2. Generate CSV + JSON + HTML reports
# 3. Start HTTP server on http://localhost:8000
# 4. Auto-open browser to interactive report
# 5. Keep running until Ctrl+C

# Advanced options
./mapper.py --parallel 8              # Faster analysis (8 workers)
./mapper.py --port 9000               # Use port 9000 instead
./mapper.py --no-browser              # Don't auto-open browser
./mapper.py --no-serve                # Just generate reports, no server
./mapper.py --refresh-s3              # Force S3 refresh (ignore cache)
```

**Note:** After first run, S3 listing is cached for 24 hours. Use `--refresh-s3` to force refresh.

## Output Files

| File | Description |
|------|-------------|
| `all_blob_history.csv` | Complete history with release tags |
| `uuid_mapping_current.csv` | Current UUID → filename + releases |
| `blobs_by_release.csv` | **NEW!** Blobs grouped by BOSH release |
| `s3_uuid_files.csv` | All UUID files in S3 |
| `orphaned_blobs.csv` | Orphaned blobs with historical context |
| `summary.json` | Statistics summary |
| `report.html` | **Interactive web dashboard with search** |

## Example Output

### Summary
```
Total blob history entries: 12,543
Unique UUIDs (historical):  8,234
Current active UUIDs:       3,142
UUIDs in S3 bucket:         4,351
Orphaned blobs:             1,209  (45.67 GB)
```

### UUID Mapping (uuid_mapping_current.csv)
```csv
uuid,filename,size,sha,repo,commit,date,author
29a57fe6-b667-4261-6725-124846b7bb47,java-buildpack/java-buildpack-v4.77.0.zip,253254,abc123...,java-buildpack-release,def456...,2026-01-07 12:59:40,CI Bot
```

### Orphaned Blobs (orphaned_blobs.csv)
```csv
uuid,size,last_modified,status
abc-123-def,752104923,2024-07-11 22:44:12,orphaned
xyz-789-ghi,751985031,2024-07-11 22:44:15,orphaned
```

## Why Historical Analysis?

BOSH blobs come from three sources and are immutable:

### 1. Source Dependencies (config/blobs.yml)
When buildpacks upgrade dependencies, the OLD blob remains in S3:

```
Timeline:
├─ 2024-01-01: Upload java-buildpack-v4.75.0.zip → UUID: abc-123
├─ 2024-06-01: Upload java-buildpack-v4.76.0.zip → UUID: xyz-789
└─ 2026-01-07: Upload java-buildpack-v4.77.0.zip → UUID: 29a57fe6...

Current blobs.yml only references: 29a57fe6...
But S3 still has: abc-123, xyz-789, 29a57fe6...
```

### 2. Compiled Packages (.final_builds/packages/)
BOSH compiles packages for each stack (cflinuxfs3, cflinuxfs4). Each compilation produces a unique blob:

```
hwc-buildpack-release/.final_builds/packages/hwc-buildpack-windows/
  ├─ d5be3d30e482... → UUID: 28da823b-1887-43fb-6163-1e382c205176
  └─ 0b7cc958581d... → UUID: 8361a9f7-6bf3-4ed6-60bd-940ba0f7f3fd
```

### 3. Compiled Jobs (.final_builds/jobs/)
BOSH jobs are also compiled and stored as blobs:

```
binary-buildpack-release/.final_builds/jobs/binary-buildpack/
  ├─ 36f2e1a89f19... → UUID: aae2d69f-10ae-40a4-5940-e83ec141d8c3
  └─ 627f036b1503... → UUID: 7865fe4d-ce62-416f-6563-109982043cf9
```

**Without .final_builds scanning**, these UUIDs appear as "unknown orphans".  
**With complete analysis**, we know they're compiled packages/jobs for specific BOSH releases.

## Use Cases

### 1. Identify Unknown Blobs
```bash
# What is this UUID?
grep "abc-123-def" output/uuid_mapping_current.csv
# Result: java-buildpack/java-buildpack-v4.75.0.zip
```

### 2. Find Orphaned Blobs
```bash
# Which blobs can be deleted?
head -10 output/orphaned_blobs.csv
# Shows largest orphaned blobs first
```

### 3. Audit Blob Usage
```bash
# How many java-buildpack blobs exist?
grep "java-buildpack" output/all_blob_history.csv | wc -l
```

### 4. Generate Cleanup Script
```bash
# Delete orphaned blobs older than 1 year
awk -F, 'NR>1 && $3 < "2025-01-01" {
  print "aws s3 rm s3://buildpacks.cloudfoundry.org/" $1
}' output/orphaned_blobs.csv > cleanup.sh
```

### 5. Add S3 Object Tags
```bash
# Tag S3 objects with original filenames
while IFS=, read uuid filename rest; do
  aws s3api put-object-tagging \
    --bucket buildpacks.cloudfoundry.org \
    --key "$uuid" \
    --tagging "TagSet=[{Key=OriginalFilename,Value=$filename}]"
done < output/uuid_mapping_current.csv
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  1. Clone All Buildpack Release Repos (13 repos)           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  2a. For Each Repo: Get All Commits Touching blobs.yml     │
│      git log --all -- config/blobs.yml                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  2b. For Each Repo: Scan .final_builds/ directories        │
│      .final_builds/packages/*/index.yml                     │
│      .final_builds/jobs/*/index.yml                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  3. For Each Commit: Extract Blob Entries                  │
│     git show <commit>:config/blobs.yml | parse YAML        │
│     Parse .final_builds index.yml for blobstore_id         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Build Complete History Database                         │
│     UUID → Filename × Commit × Date × Author × Source       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Fetch Current S3 Bucket Contents (with 24h cache)      │
│     aws s3 ls --recursive | filter UUIDs                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Cross-Reference: Find Orphaned Blobs                    │
│     S3 UUIDs - (blobs.yml + .final_builds) = Orphaned      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Generate Reports (CSV, JSON, HTML)                      │
└─────────────────────────────────────────────────────────────┘
```

## Performance

- **Repositories:** 13
- **Average commits per repo:** ~500
- **Total commits analyzed:** ~6,500
- **Execution time (4 parallel workers):** 5-10 minutes
- **Execution time (single-threaded):** 20-30 minutes

Bottlenecks:
- Git operations (cloning/fetching)
- S3 listing (34k files)
- Network latency

## Advanced Options

```bash
# Increase parallelism
./mapper.py --parallel 8

# Use different workspace
./mapper.py --work-dir /tmp/mapper

# Different output location
./mapper.py --output-dir ./my-reports

# Different bucket
./mapper.py --bucket my-other-bucket
```

## Integration

### Concourse CI

```yaml
- task: generate-uuid-mapping
  file: buildpacks-ci/tools/uuid-mapper/task.yml
  params:
    AWS_ACCESS_KEY_ID: ((aws.access_key))
    AWS_SECRET_ACCESS_KEY: ((aws.secret_key))
    BUCKET: buildpacks.cloudfoundry.org
    PARALLEL_JOBS: 8
```

### Makefile

```bash
make install   # Install dependencies
make run       # Run Python version
make run-bash  # Run bash version
make clean     # Clean workspace
make test      # Quick test
```

## Troubleshooting

**"Failed to clone repository"**
- Check network/GitHub access
- Some repos might be private
- Remove inaccessible repos from code

**"No module named yaml"**
```bash
pip install PyYAML
```

**"aws: command not found"**
```bash
pip install awscli && aws configure
```

**Slow execution**
- Increase `--parallel` workers
- Check network connection
- Use Python version (faster than bash)

## Files

```
tools/uuid-mapper/
├── mapper.py          # Python implementation (recommended)
├── mapper.sh          # Bash implementation
├── requirements.txt   # Python dependencies
├── task.yml          # Concourse task definition
├── Makefile          # Make targets
├── README.md         # This file
├── USAGE.md          # Detailed usage guide
└── .gitignore        # Git ignore rules
```

## Documentation

- **README.md** (this file) - Overview and quick start
- **USAGE.md** - Detailed usage guide with examples
- **task.yml** - Concourse CI integration

## Contributing

Improvements welcome! Areas for enhancement:
- Add more buildpack release repos as they're created
- Optimize git operations (shallow clones, sparse checkouts)
- Add caching for incremental runs
- Web UI for interactive exploration
- Database backend (SQLite/Postgres) for query interface

## Related

- **S3_BUCKET_INVESTIGATION.md** - Original investigation report
- **buildpacks-ci/tasks/cf-release/** - Where UUIDs are created

## License

Apache 2.0 (same as buildpacks-ci)

## Contact

Cloud Foundry Buildpacks Team
