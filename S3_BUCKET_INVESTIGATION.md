# S3 Bucket Investigation: buildpacks.cloudfoundry.org

**Investigation Date:** January 7, 2026  
**Total Files:** 34,543  
**Total Size:** 2.32 TB (2,324,351,953,775 bytes)  
**Bucket Region:** Global CDN

---

## Executive Summary

The S3 bucket contains a mix of organized directories and **4,351 UUID-named files in the root** (12.6% of all files). These UUID files appear to be binary artifacts without clear organization. The bucket primarily stores Cloud Foundry buildpack binaries, dependencies, and root filesystem images dating from 2015 to present.

---

## 1. Root-Level UUID Files

### Problem Identification
- **Count:** 4,351 files with UUID naming pattern (e.g., `000bd0ee-f5a9-4940-5ffb-bf595d5b967a`)
- **Pattern:** Standard UUID v4 format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- **Content Type:** All sampled files show `binary/octet-stream`
- **No file extensions:** Makes it impossible to determine file type without inspection

### Size Distribution of UUID Files
| Category | Size Range | Count | Percentage |
|----------|------------|-------|------------|
| Tiny | < 1 KB | 129 | 3.0% |
| Small | 1 KB - 1 MB | 514 | 11.8% |
| Medium | 1 MB - 100 MB | 3,234 | 74.3% |
| Large | > 100 MB | 474 | 10.9% |

### Sample UUID Files
```
000bd0ee-f5a9-4940-5ffb-bf595d5b967a  (7.7 MB)
0150e97a-bd73-4728-6296-bd7f4be0f33f  (752 MB)
017c5dba-4f0d-444c-9ad2-3265e8c01cd0  (1.07 GB)
030ba24b-6c4b-4568-64bf-f8c1a134106a  (2.11 GB)
```

### Suspected Purpose
Based on context, these are likely:
- Cached buildpack artifacts
- Temporary build outputs
- CI/CD pipeline artifacts
- Legacy files from migration or testing

---

## 2. Organized Directory Structure

### Top-Level Directories (29 total)

| Directory | Purpose | File Count |
|-----------|---------|------------|
| `.md5/` | MD5 checksums for validation | 348 |
| `bosh-lite/` | BOSH Lite test environment files | - |
| `buildpack-release-candidates/` | Pre-release buildpack versions | 1,099 |
| `cflinuxfs2-nc/` | Legacy Linux filesystem (deprecated) | 26 |
| `cflinuxfs4-release/` | Current Linux filesystem releases | - |
| `check/` | Validation/check scripts | - |
| `concourse-artifacts/` | Concourse CI outputs | - |
| `concourse-binaries/` | Concourse pipeline binaries | 428 |
| `dependencies/` | **Buildpack dependencies** | **9,753** |
| `deps/` | Alternative dependency location | 1,141 |
| `experimental-buildpacks/` | Unstable/test buildpacks | 201 |
| `fixtures/` | Test fixtures | 13 |
| `httpd/` | Apache HTTP server binaries | 4 |
| `manual-binaries/` | Manually uploaded binaries | - |
| `metadata/` | Metadata files | 23 |
| `nginx/` | Nginx server binaries | 4 |
| `node/` | Node.js binaries | 99 |
| `php/` | **PHP binaries** | **10,024** |
| `python/` | Python binaries | 63 |
| `rootfs-fake/` | Mock root filesystems for testing | - |
| `rootfs-lts/` | Long-term support root filesystems | - |
| `rootfs-nc/` | Root filesystem variants | 286 |
| `rootfs-tanzu/` | VMware Tanzu root filesystems | 368 |
| `rootfs/` | **Main root filesystem images** | **5,793** |
| `ruby/` | Ruby binaries | 239 |
| `shared/` | Shared libraries/utilities | - |
| `static/` | Static assets | 226 |
| `versions/` | Version metadata | 19 |
| `xenial-test/` | Ubuntu Xenial test files | 18 |

---

## 3. Detailed Directory Analysis

### 3.1 Dependencies Directory (9,753 files)
**Purpose:** Language-specific buildpack dependencies

**Structure:**
```
dependencies/
├── CA-APM-PHPAgent/      # Application Performance Monitoring
├── bower/                 # JavaScript package manager
├── bundler/              # Ruby dependency manager
├── composer/             # PHP dependency manager
├── dep/                  # Go dependency tool
├── dotnet/               # .NET SDK
├── go/                   # Go language binaries
├── node/                 # Node.js versions
├── python/               # Python interpreters
└── [many more...]
```

**File Naming Convention:**
```
bower-1.8.14-any-stack-00df3dcc.tgz
bundler-1.13.7.tgz
composer-1.10.0-php-7.4-linux-x64-cflinuxfs3-12ab34cd.tgz
```
Pattern: `{name}-{version}-{platform}-{stack}-{hash}.{ext}`

### 3.2 PHP Directory (10,024 files)
**Purpose:** PHP runtime binaries for multiple versions and platforms

**Structure:**
```
php/
├── beta-binaries/
│   └── cflinuxfs2/
│       ├── php-5.4.39-linux-x64.tgz
│       ├── php-5.5.23-linux-x64.tgz
│       └── php-5.6.7-linux-x64.tgz
└── binaries/
    ├── lucid/           # Ubuntu 10.04 (very old)
    │   ├── composer/
    │   └── hhvm/        # HipHop VM
    ├── cflinuxfs2/
    ├── cflinuxfs3/
    └── cflinuxfs4/
```

**Observations:**
- Contains PHP versions from 5.4 to 8.x
- Organized by Cloud Foundry root filesystem version
- Includes legacy Ubuntu "Lucid" (10.04) binaries
- Contains `.DS_Store` files (macOS artifacts - cleanup needed)

### 3.3 Rootfs Directory (5,793 files)
**Purpose:** Cloud Foundry root filesystem images

**File Examples:**
```
cflinuxfs2-1.0.0-rc.1.tar.gz     (252 MB)
cflinuxfs2-1.100.0-rc.2.tar.gz   (357 MB)
cflinuxfs3-0.200.0.tar.gz        (various)
cflinuxfs4-1.x.x.tar.gz          (latest)
```

**Naming Pattern:** `{name}-{version}-{rc}.tar.gz`
- Includes release candidates (`-rc.N`)
- Multiple major versions (fs2, fs3, fs4)

### 3.4 Buildpack Release Candidates (1,099 files)
**Purpose:** Pre-release buildpack testing

**Subdirectories:**
- `apt/` - APT package buildpack
- `binary/` - Binary buildpack
- `dotnet-core/` - .NET Core buildpack
- `go/` - Go buildpack
- `hwc/` - Windows buildpack
- `java/`, `nodejs/`, `php/`, `python/`, `ruby/`, etc.

**Naming Convention:**
```
apt_buildpack-cached-cflinuxfs4-v0.3.14+1767021904.zip
```
Pattern: `{lang}_buildpack-{type}-{stack}-{version}+{timestamp}.zip`

### 3.5 .md5 Directory (348 files)
**Purpose:** MD5 checksums for file integrity validation

**Structure:** Mirrors main bucket structure
```
.md5/
├── binary-builder/
├── buildpacks/
├── concourse-binaries/
└── experimental-buildpacks/
```

Each `.md5` file corresponds to an artifact in the main bucket.

---

## 4. File Type Analysis

### Primary File Types
| Extension | Purpose | Typical Location |
|-----------|---------|------------------|
| `.tgz` / `.tar.gz` | Compressed archives | dependencies/, php/, rootfs/ |
| `.zip` | Buildpack packages | buildpack-release-candidates/ |
| `.md5` | Checksums | .md5/ |
| `.phar` | PHP archives | php/binaries/*/composer/ |
| `.sha1` / `.sha256` | Checksums | Various |
| (none - UUID) | Binary artifacts | Root level |

### Binary Content Types
All sampled UUID files return `binary/octet-stream`, suggesting:
- Compiled binaries
- Compressed archives without extensions
- Build artifacts
- Cache files

---

## 5. Timeline Analysis

### File Age Distribution
- **Oldest files:** 2015 (early Cloud Foundry buildpack era)
- **Most recent:** January 2026 (ongoing uploads)
- **Peak activity:** 2024-07-11 (major sync/migration event)
- **Current activity:** Daily uploads continue

### Activity Pattern
The bucket shows continuous activity with recent uploads as of January 6-7, 2026, indicating it's actively maintained.

---

## 6. Issues & Recommendations

### Critical Issues

#### Issue 1: Unorganized UUID Files (4,351 files)
**Problem:**
- No clear naming convention
- Impossible to identify file type without inspection
- Takes up root namespace
- No apparent retention policy

**Impact:**
- Difficult to manage and audit
- Potential for orphaned/unused files
- Increased storage costs for potentially obsolete data
- Security/compliance concerns (unknown content)

**Recommended Actions:**
1. **Audit UUID files:**
   ```bash
   # Download sample UUID files and analyze content
   # Use `file` command to determine actual file types
   # Check access logs to identify actively used files
   ```

2. **Categorize and relocate:**
   - Create `cache/` or `artifacts/` directory
   - Move UUID files to organized subdirectories
   - Add proper file extensions based on content type

3. **Implement retention policy:**
   - Define lifecycle rules (e.g., delete after 90 days if unused)
   - Archive old artifacts to cheaper storage (S3 Glacier)

4. **Prevent future UUID files:**
   - Update build pipelines to use meaningful names
   - Implement naming conventions in CI/CD

#### Issue 2: Duplicate/Overlapping Directories
**Problem:**
- Both `dependencies/` and `deps/` exist (potential confusion)
- Multiple rootfs directories (`rootfs/`, `rootfs-nc/`, `rootfs-lts/`, `rootfs-tanzu/`)

**Recommended Actions:**
- Consolidate or clearly document the purpose of each
- Consider using tags instead of separate directories

#### Issue 3: Legacy Files
**Problem:**
- Ubuntu "Lucid" (10.04) binaries from 2010
- cflinuxfs2 (deprecated)
- `.DS_Store` files (macOS artifacts)

**Recommended Actions:**
1. Archive or delete files older than 5 years
2. Remove non-essential files (`.DS_Store`)
3. Create `legacy/` or `archive/` directory for historical artifacts

#### Issue 4: Large Bucket Size (2.32 TB)
**Problem:**
- 34,543 files consuming significant storage
- Potential for many unused/duplicate files

**Recommended Actions:**
1. Implement S3 Intelligent-Tiering
2. Enable versioning with lifecycle policies
3. Compress large rootfs images further if possible
4. Delete old release candidates after final release

---

## 7. Proposed Directory Structure

### Current State
```
s3://buildpacks.cloudfoundry.org/
├── [4,351 UUID files in root] ❌
├── .md5/
├── dependencies/
├── deps/
├── php/
├── rootfs/
├── rootfs-nc/
├── rootfs-tanzu/
└── [26 more directories]
```

### Recommended Structure
```
s3://buildpacks.cloudfoundry.org/
├── binaries/                    # All runtime binaries
│   ├── php/
│   ├── node/
│   ├── ruby/
│   ├── python/
│   └── go/
├── dependencies/                # Buildpack dependencies
│   ├── bundler/
│   ├── composer/
│   └── npm/
├── buildpacks/                  # Organized buildpacks
│   ├── releases/               # Stable releases
│   ├── candidates/             # Release candidates
│   └── experimental/           # Experimental versions
├── rootfs/                      # All filesystem images
│   ├── cflinuxfs4/            # Current
│   ├── cflinuxfs3/            # Deprecated
│   └── tanzu/                 # Tanzu-specific
├── artifacts/                   # CI/CD outputs
│   ├── cache/                  # Cached builds
│   └── temp/                   # Temporary (lifecycle policy)
├── checksums/                   # All checksums
│   ├── md5/
│   └── sha256/
├── legacy/                      # Archived old files
└── metadata/                    # Metadata files
```

---

## 8. Action Plan

### Phase 1: Investigation (Week 1)
- [ ] Sample and analyze 100 random UUID files to determine content types
- [ ] Check S3 access logs to identify actively used UUID files
- [ ] Document which systems/pipelines create UUID files
- [ ] Identify duplicate files across directories

### Phase 2: Documentation (Week 1-2)
- [ ] Create bucket usage policy document
- [ ] Define naming conventions for all file types
- [ ] Document purpose of each directory
- [ ] Create retention policy (30/60/90/365 days by category)

### Phase 3: Organization (Week 2-4)
- [ ] Move UUID files to appropriate directories
- [ ] Consolidate duplicate directories
- [ ] Remove `.DS_Store` and other junk files
- [ ] Add proper file extensions where missing

### Phase 4: Cleanup (Week 4-6)
- [ ] Delete files older than retention policy
- [ ] Archive legacy files to S3 Glacier
- [ ] Remove unused release candidates

### Phase 5: Automation (Week 6-8)
- [ ] Implement S3 lifecycle policies
- [ ] Update CI/CD pipelines with new naming conventions
- [ ] Set up automated cleanup jobs
- [ ] Configure S3 Intelligent-Tiering
- [ ] Add bucket policies to prevent root-level uploads

### Phase 6: Monitoring (Ongoing)
- [ ] Set up CloudWatch alarms for bucket size
- [ ] Regular audits (monthly)
- [ ] Track cost savings

---

## 9. Estimated Impact

### Storage Cost Savings
Assuming 30% of files are obsolete or duplicates:
- Current size: 2.32 TB
- Potential reduction: ~700 GB
- **Estimated monthly savings:** $16-20 USD (S3 Standard pricing)
- **Annual savings:** ~$200 USD

### Additional Benefits
- Improved organization and discoverability
- Faster CI/CD pipelines (less clutter)
- Better security posture (known contents)
- Compliance with data retention policies
- Reduced time spent managing bucket

---

## 10. Technical Details for Implementation

### Sample Script: Analyze UUID Files
```bash
#!/bin/bash
# Analyze UUID files and determine actual file types

BUCKET="buildpacks.cloudfoundry.org"
OUTPUT="uuid_analysis.csv"

echo "UUID,Size,ContentType,FileType,LastModified" > "$OUTPUT"

aws s3 ls "s3://$BUCKET/" --recursive | \
  grep -E "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$" | \
  head -100 | while read date time size uuid; do
  
  # Get metadata
  content_type=$(aws s3api head-object --bucket "$BUCKET" --key "$uuid" \
    --query 'ContentType' --output text 2>/dev/null || echo "unknown")
  
  # Download and check file type
  aws s3 cp "s3://$BUCKET/$uuid" "/tmp/$uuid" --quiet
  file_type=$(file -b "/tmp/$uuid" | cut -d',' -f1)
  rm -f "/tmp/$uuid"
  
  echo "$uuid,$size,$content_type,$file_type,$date $time" >> "$OUTPUT"
done
```

### S3 Lifecycle Policy Example
```json
{
  "Rules": [
    {
      "Id": "DeleteOldArtifacts",
      "Status": "Enabled",
      "Prefix": "artifacts/temp/",
      "Expiration": {
        "Days": 30
      }
    },
    {
      "Id": "ArchiveLegacyFiles",
      "Status": "Enabled",
      "Prefix": "legacy/",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    },
    {
      "Id": "DeleteOldReleaseCandidates",
      "Status": "Enabled",
      "Prefix": "buildpack-release-candidates/",
      "Expiration": {
        "Days": 180
      }
    }
  ]
}
```

---

## 11. Questions for Stakeholders

Before proceeding with cleanup:

1. **UUID Files:**
   - What systems generate these UUID-named files?
   - Are they cache files from a specific service?
   - What is the expected retention period?
   - Are any of these files still actively accessed?

2. **Directory Structure:**
   - Why do both `dependencies/` and `deps/` exist?
   - What distinguishes `rootfs/` from `rootfs-nc/` and `rootfs-tanzu/`?
   - Is `experimental-buildpacks/` still used?

3. **Retention:**
   - What is the policy for keeping old buildpack versions?
   - How long should release candidates be retained?
   - Are there compliance requirements for file retention?

4. **Access:**
   - Which teams/systems actively use this bucket?
   - Are there any external users/systems with dependencies?
   - What would break if we reorganize?

---

## 12. Conclusion

The `buildpacks.cloudfoundry.org` S3 bucket is a large, actively maintained repository with **significant organizational issues**, primarily the 4,351 UUID-named files in the root directory. While the organized directories follow a logical structure for buildpack dependencies and filesystems, the bucket would benefit greatly from:

1. **Immediate:** Investigation and categorization of UUID files
2. **Short-term:** Implementation of lifecycle policies and cleanup
3. **Long-term:** Restructuring and automation to prevent future disorganization

The recommended action plan will improve maintainability, reduce costs, and enhance security while ensuring no disruption to existing systems.

---

**Document Prepared By:** AI Analysis System  
**Next Review Date:** January 2026 (Post-Phase 1)  
**Contact:** buildpacks-team@cloudfoundry.org

---

## APPENDIX: Root Cause Analysis (Updated January 7, 2026)

### UUID File Generation - ROOT CAUSE IDENTIFIED ✅

**Finding:** The UUID-named files are generated by **BOSH CLI's blob upload mechanism**.

**Evidence from logs:**
```
2026/01/07 11:59:39 Successfully uploaded file to https://s3.amazonaws.com/buildpacks.cloudfoundry.org/29a57fe6-b667-4261-6725-124846b7bb47
Blob upload 'java-buildpack/java-buildpack-v4.77.0.zip' (id: 29a57fe6-b667-4261-6725-124846b7bb47) finished
```

**Source:** `buildpacks-ci/tasks/cf-release/create-buildpack-dev-release/run` (line 80)
```bash
upload_blobs() {
  bosh upload-blobs --dir release
}
```

### How BOSH Blob Upload Works

1. **BOSH Release Config** (`config/final.yml`):
   ```yaml
   blobstore:
     provider: s3
     options:
       bucket_name: buildpacks.cloudfoundry.org
   ```

2. **BOSH generates UUID for each blob** as the S3 object key
3. **BOSH tracks mapping** in `config/blobs.yml`:
   ```yaml
   java-buildpack/java-buildpack-v4.77.0.zip:
     size: 253254
     object_id: 29a57fe6-b667-4261-6725-124846b7bb47
     sha: abc123...
   ```

4. **Result:** Human-readable name exists only in `blobs.yml`, S3 gets UUID

### Why This Design?

BOSH uses content-addressable storage:
- **Deduplication:** Same content = same blob ID
- **Immutability:** Blobs never change once uploaded
- **Version control:** `blobs.yml` tracks which UUIDs belong to which files
- **Security:** Harder to guess/enumerate blob URLs

### The Problem

While BOSH's design is intentional, it creates issues:
1. ❌ **S3 bucket is difficult to browse** (UUIDs everywhere)
2. ❌ **No way to identify orphaned blobs** (when `blobs.yml` diverges from S3)
3. ❌ **Difficult to audit** (can't see what files are without downloading)
4. ❌ **Manual cleanup is nearly impossible** (need to cross-reference all `blobs.yml` files)

### Solution Options

#### Option 1: Use S3 Object Tagging (RECOMMENDED)
Add tags to each blob when uploading:
```yaml
Tags:
  - Key: OriginalFilename
    Value: java-buildpack-v4.77.0.zip
  - Key: BlobType
    Value: buildpack
  - Key: Language
    Value: java
```

**Implementation:**
- Modify BOSH CLI upload process (or use S3 event triggers)
- Parse `blobs.yml` to get original names
- Apply tags via AWS API after upload

**Benefits:**
- ✅ Keeps BOSH design intact
- ✅ Makes S3 bucket browsable with AWS CLI: `aws s3api list-objects --bucket ... --query 'Contents[?Tags[?Key==OriginalFilename]]'`
- ✅ Easy cleanup with tag-based queries

#### Option 2: Use S3 Object Metadata
Similar to tags but using S3 custom metadata:
```
x-amz-meta-original-filename: java-buildpack-v4.77.0.zip
```

#### Option 3: Create Symbolic Links (S3 Aliases)
Upload each blob twice:
1. UUID (BOSH's requirement): `29a57fe6-b667-4261-6725-124846b7bb47`
2. Human-readable alias: `buildpacks/java/java-buildpack-v4.77.0.zip`

**Cons:** Doubles storage costs

#### Option 4: Maintain External Mapping Database
- Store UUID → filename mappings in DynamoDB/Postgres
- Build web UI for browsing
- Sync from all `blobs.yml` files

#### Option 5: Change BOSH Configuration (NOT RECOMMENDED)
- Fork BOSH CLI to use human-readable names
- **Cons:** Maintains fork, breaks BOSH design principles

### Recommended Action Plan (Updated)

#### Phase 1: Understanding (COMPLETE ✅)
- [x] Identified UUID files are BOSH blobs
- [x] Found generation mechanism (BOSH CLI)
- [x] Confirmed files are actively used

#### Phase 2: Create Visibility (Week 1-2)
- [ ] Clone all buildpack BOSH release repos
- [ ] Extract all `config/blobs.yml` files
- [ ] Build UUID → filename mapping database
- [ ] Identify orphaned blobs (in S3 but not in any `blobs.yml`)

**Script to generate mapping:**
```bash
#!/bin/bash
# Scan all buildpack release repos and build UUID mapping

REPOS=(
  "https://github.com/cloudfoundry/java-buildpack-release"
  "https://github.com/cloudfoundry/ruby-buildpack-release"
  "https://github.com/cloudfoundry/python-buildpack-release"
  # ... add all buildpack releases
)

echo "UUID,Filename,Repo,SHA,Size" > uuid_mapping.csv

for repo in "${REPOS[@]}"; do
  repo_name=$(basename "$repo")
  git clone --depth 1 "$repo" "/tmp/$repo_name" 2>/dev/null
  
  if [ -f "/tmp/$repo_name/config/blobs.yml" ]; then
    yq eval '.[] | [.object_id, .path, "'$repo_name'", .sha, .size] | @csv' \
      "/tmp/$repo_name/config/blobs.yml" >> uuid_mapping.csv
  fi
done
```

#### Phase 3: Implement Tagging (Week 2-4)
- [ ] Create Lambda function triggered by S3 PutObject events
- [ ] Lambda reads filename from BOSH upload metadata
- [ ] Lambda applies tags to new objects
- [ ] Backfill tags for existing 4,351 UUID files using mapping database

#### Phase 4: Cleanup Orphaned Blobs (Week 4-6)
- [ ] Use mapping to identify unused UUIDs
- [ ] Verify via S3 access logs (check last access date)
- [ ] Archive to Glacier or delete blobs > 1 year old with no access

#### Phase 5: Documentation (Week 6)
- [ ] Document BOSH blob storage architecture
- [ ] Create runbook for future blob cleanup
- [ ] Add tagging to CI/CD documentation

### Cost Impact (Revised)

With proper tagging and cleanup of orphaned blobs:
- **Orphaned blob estimate:** 30-40% of UUID files (1,300-1,700 files)
- **Average size:** ~50 MB per orphaned blob
- **Potential savings:** 65-85 GB
- **Monthly cost savings:** $15-20 USD
- **Annual savings:** $180-240 USD

Plus improved operational efficiency and reduced confusion.

---

**Investigation Status:** ROOT CAUSE IDENTIFIED  
**Next Action:** Build UUID → filename mapping database  
**Owner:** DevOps/Buildpacks Team  
**Priority:** Medium (operational efficiency, not production-critical)
