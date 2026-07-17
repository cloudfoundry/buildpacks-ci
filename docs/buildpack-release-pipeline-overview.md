# Buildpack Release Pipeline Overview

## What is the Buildpack Release Pipeline?

The buildpack release pipeline is an **automated CI/CD system** that tests, packages, and releases Cloud Foundry buildpacks to GitHub. It runs unit tests, integration tests, builds buildpack artifacts for each stack, and publishes GitHub releases with a single manual trigger.

**Think of it as:** The complete test-and-release workflow that takes buildpack code changes, validates them through multiple test stages, packages them for each stack (cflinuxfs4, cflinuxfs5), and creates GitHub releases automatically.

---

## Why Do We Need It?

### With the Buildpack Release Pipeline
- ✅ **Automated testing**: Unit and integration tests run on every commit
- ✅ **Multi-stack builds**: Creates buildpack artifacts for all supported stacks
- ✅ **Version management**: Automatically increments version numbers
- ✅ **GitHub releases**: Publishes releases with changelogs and downloadable artifacts
- ✅ **Quality gates**: PRs must pass all tests before merging
- ✅ **Reproducible builds**: Consistent packaging process

**Result:** Reliable, tested buildpack releases with minimal manual steps.

---

## How It Works (Simple Overview)

```
┌──────────────────┐
│  PR Merged       │  Code merged to master branch
│  (Trigger)       │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Unit Tests      │  Run Go/Ruby tests
│  (Validation)    │  Ginkgo test suite
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│  Docker Integration Tests                        │
│  (Fast Path - Per Stack)                         │
│                                                  │
│  • specs-switchblade-docker-cflinuxfs4           │
│  • specs-switchblade-docker-cflinuxfs5           │
│                                                  │
│  Docker-based, lightweight, ~15-30 min           │
└────────┬─────────────────────────────────────────┘
         │
         ├─────────────────────────────────────────┐
         │                                         │
         ▼                                         ▼
┌──────────────────┐                    ┌──────────────────┐
│  Detect & Build  │                    │  Real CF E2E     │
│  Artifacts       │                    │  Integration     │
│  (Packaging)     │                    │  Tests           │
│                  │                    │  (Heavy Path)    │
│  Creates:        │                    │                  │
│  - Uncached zip  │                    │  Provisions BOSH │
│  - Cached zips   │                    │  + CF on GCP     │
│    (per stack)   │                    │  ~1.5-3 hours    │
│  Uploads to S3   │                    │                  │
└────────┬─────────┘                    │  Triggers on     │
         │                              │  latest passed   │
         │                              │  commit when job │
         │                              │  is free         │
         │                              └──────────────────┘
         ▼
┌──────────────────┐
│  Ship-It Ready   │  ⏸️  Waits for manual trigger
│  (Manual Gate)   │
└────────┬─────────┘
         │  [Maintainer clicks "ship-it"]
         ▼
┌──────────────────┐
│  Finalize        │  - Checks tag not already used
│  Release         │  - Generates changelog (RECENT_CHANGES)
│                  │  - Creates GitHub release
└────────┬─────────┤  - Uploads .zip artifacts
         │         │  - Bumps version (patch++)
         ▼         │
┌──────────────────┐
│  GitHub Release  │  v1.10.49 published!
│  Published       │
└──────────────────┘
```

---

## Key Concepts

### 1. **Pipeline Jobs**

The pipeline consists of several jobs with different purposes:

| Job | Purpose | Trigger | Duration |
|-----|---------|---------|----------|
| **specs-unit** | Run unit tests (Ginkgo) | Every commit to master | ~2-5 min |
| **specs-switchblade-docker-{stack}** | Docker-based integration tests (lightweight) | After unit tests pass | ~15-30 min |
| **create-cf-infrastructure-and-execute-integration-test-for-{language}** | Full E2E tests with real CF deployment | After all docker tests pass (auto-triggered on latest commit) | ~1.5-3 hrs |
| **detect-new-version-and-upload-artifacts** | Build and upload artifacts | After switchblade tests pass | ~5-10 min |
| **ship-it** | Create GitHub release | Manual trigger only | ~5-10 min |

#### Two Types of Integration Tests

**Docker-based tests (Fast Path):**
- Job: `specs-switchblade-docker-{stack}`
- Uses Docker containers to simulate CF environment
- Faster, lightweight, runs on every commit
- Good for catching most issues quickly
- Required gate for artifact building

**Real CF tests (Full E2E Path):**
- Job: `create-cf-infrastructure-and-execute-integration-test-for-{language}`
- Provisions actual BOSH + Cloud Foundry infrastructure on GCP
- Deploys test applications to real CF
- Slower, resource-intensive, auto-triggers after docker tests pass
- Catches environment-specific issues
- Most comprehensive validation

### 2. **Buildpack Artifacts**

Two types of buildpack artifacts are created:

**Uncached Buildpack:**
- Contains only buildpack source code
- Smaller file size (~few MB)
- Downloads dependencies at staging time
- Filename: `go-buildpack-v1.10.49.zip`

**Cached Buildpack:**
- Contains buildpack source + pre-downloaded dependencies
- Larger file size (~hundreds of MB)
- No internet required at staging time
- Filename: `go-buildpack-cached-cflinuxfs4-v1.10.49.zip`

Each stack gets its own cached buildpack, but uncached is stack-agnostic.

### 3. **Version Management**

Version is stored in the `VERSION` file in the buildpack repository:

**Current version:** `1.10.49` (read from VERSION file)

**After ship-it:**
- GitHub release created: `v1.10.49`
- VERSION file updated: `1.10.49` → `1.10.50`
- Commit message: `[ci skip] bump to 1.10.50`

The `[ci skip]` prefix prevents the version bump commit from triggering a new pipeline run (avoiding infinite loops).

### 4. **Stacks**

Buildpacks must work on multiple CF stacks:
- **cflinuxfs4** - Ubuntu 22.04 (Jammy)
- **cflinuxfs5** - Ubuntu 24.04 (Noble)

Integration tests run separately for each stack to ensure compatibility.

---

## Pipeline Configuration

### Location
`buildpacks-ci/pipelines/buildpack/`

### Key Files

```
buildpack/
├── pipeline.yml           # Main pipeline template (ytt)
├── config.yml            # Global buildpack pipeline config
├── go-values.yml         # Go buildpack specific values
├── ruby-values.yml       # Ruby buildpack specific values
├── nodejs-values.yml     # Node.js buildpack specific values
└── ...                   # Other buildpack-specific values
```

### Per-Buildpack Values

Each buildpack has a values file (e.g., `go-values.yml`):

```yaml
#@data/values
---
language: go
organization: cloudfoundry
buildpacks_github_org: cloudfoundry
buildpack:
  branch: master
  stacks: ['cflinuxfs4', 'cflinuxfs5']
```

**What this does:**
- Defines which stacks to test/build
- Sets GitHub organization
- Specifies branch to watch

---

## Typical Workflow

### Daily Development (Automatic)

**When a PR is merged:**

1. 🔄 **Code merged to master**

2. ⚡ **Unit tests trigger** (`specs-unit` job)
   - Runs Go/Ruby unit tests with Ginkgo
   - ~2-5 minutes

3. ⚡ **Docker-based integration tests** (lightweight, fast - per stack)
   - `specs-switchblade-docker-cflinuxfs4`
   - `specs-switchblade-docker-cflinuxfs5`
   - Tests buildpack staging using Docker containers
   - No real CF deployment required
   - ~15-30 minutes per stack
   - Runs in parallel

4. ⚡ **Real CF integration tests** (heavy, end-to-end - auto-triggered)
   - Job: `create-cf-infrastructure-and-execute-integration-test-for-{language}`
   - **When it runs:** Automatically triggered after ALL docker tests pass for a commit
   - **Serial execution:** Only one instance runs at a time
   - **Smart triggering:** If multiple commits pass while this runs, only the **latest** queues next
   - **Infrastructure setup:**
     - Creates BOSH environment on GCP (bbl-up)
     - Deploys full Cloud Foundry instance
     - Configures DNS, load balancers
     - ~45-60 minutes
   - **Runs comprehensive tests:**
     - Full integration tests (uncached and cached buildpacks)
     - Tests against real CF environment per stack
     - ~40-60 minutes per stack (sequential)
   - **Cleanup:**
     - Destroys CF deployment
     - Tears down BOSH infrastructure
   - **Total time:** ~1.5-3 hours

5. ⚡ **Build artifacts** (`detect-new-version-and-upload-artifacts`)
   - Packages uncached buildpacks
   - Packages cached buildpacks (per stack)
   - Uploads to S3
   - Generates SHA256 checksums
   - ~5-10 minutes

6. ⏸️ **Ready for release** (ship-it job waits)

**Status:** All tests passed, artifacts built, waiting for manual ship-it trigger

### Release Process (Manual)

**When ready to ship a release:**

1. 👤 **Maintainer reviews**
   - Check Concourse: all jobs green
   - Verify recent changes are ready for release
   - Check VERSION file for current version

2. 👤 **Trigger ship-it**
   - Click "ship-it" job in Concourse
   - Click the `+` button to manually trigger

3. ⚡ **ship-it job runs:**
   - **check-tag-not-already-added**: Verifies v1.10.49 tag doesn't exist
   - **finalize-buildpack**: Creates release artifacts and changelog
   - **buildpack-github-release**: Publishes to GitHub
     - Tag: `v1.10.49`
     - Title: Auto-generated
     - Body: RECENT_CHANGES from CHANGELOG
     - Attachments: 
       - `go-buildpack-v1.10.49.zip` (uncached)
       - `go-buildpack-cached-cflinuxfs4-v1.10.49.zip`
       - `go-buildpack-cached-cflinuxfs5-v1.10.49.zip`
       - `.SHA256SUM.txt` files for each
   - **pivotal-buildpack-published-{stack}**: Publishes to S3
   - **version bump**: Updates VERSION file `1.10.49` → `1.10.50`

4. ✅ **Release complete**
   - GitHub release: https://github.com/cloudfoundry/go-buildpack/releases/tag/v1.10.49
   - VERSION file updated for next release
   - Artifacts available for download

**Time:** ~5-10 minutes

---

## Testing Strategy

### When to Run Which Tests

**Docker-based tests (Every commit):**
✅ Fast feedback loop
✅ Catches most common issues
✅ Part of standard PR → merge → release flow
✅ Required before artifacts are built

**Real CF tests (Automatic after Docker tests):**
✅ Auto-triggers when all docker tests pass for a commit
✅ Serial execution - one at a time (~1.5-3 hours each)
✅ Smart queuing - latest passing commit runs when job is free
✅ Full confidence with real CF environment
✅ Can also be manually triggered when needed

### Understanding Real CF Integration Tests

**Automatic triggering:**
The `create-cf-infrastructure-and-execute-integration-test-for-{language}` job automatically triggers when:
- ALL docker-based switchblade tests pass for a commit (cflinuxfs4 AND cflinuxfs5)
- The job is not already running (it's serial - one at a time)
- If multiple commits queue up, only the **latest** one runs next

**Manual triggering (optional):**
You can also trigger this job manually when needed.

**When to manually trigger:**
- You want to test a specific commit immediately (bypass the queue)
- You need to re-run after a flaky failure
- You're testing infrastructure changes
- You want extra confidence before a critical release

**How to trigger:**
```bash
# Option 1: Via Concourse UI
# Navigate to: go-buildpack pipeline
# Click: create-cf-infrastructure-and-execute-integration-test-for-go
# Click the + button to manually trigger

# Option 2: Via fly CLI
fly -t <target> trigger-job \
  -j go-buildpack/create-cf-infrastructure-and-execute-integration-test-for-go
```

**What it does:**
1. **Provisions infrastructure** (~45-60 min)
   - Creates BOSH director on GCP
   - Deploys Cloud Foundry
   - Configures DNS: `go.buildpacks.ci.cloudfoundry.org`

2. **Runs comprehensive tests** (~40-60 min per stack)
   - Integration tests with uncached buildpacks
   - Integration tests with cached buildpacks

3. **Cleans up** (~10-15 min)
   - Deletes CF deployment
   - Destroys BOSH infrastructure
   - Removes DNS records

**Cost awareness:** 
Real CF tests use GCP resources (compute, networking) and take ~3 hours. Use judiciously.

---

## Common Operations

### Manual Version Bump (Minor/Major)

**When to do this:** Before a release that includes breaking changes or new features

**Steps:**

1. **Create version bump PR:**
   ```bash
   cd go-buildpack
   git checkout -b bump-version-1.11.0
   
   # Update VERSION file
   echo "1.11.0" > VERSION
   
   # Update CHANGELOG
   vim CHANGELOG  # Add entry for v1.11.0
   
   git add VERSION CHANGELOG
   git commit -m "Bump version to 1.11.0"
   git push origin bump-version-1.11.0
   ```

2. **Create PR and merge**
   - Open PR on GitHub
   - Get review and merge

3. **Wait for pipeline**
   - Pipeline runs tests automatically
   - Artifacts built with version 1.11.0

4. **Trigger ship-it**
   - Release will be v1.11.0
   - Next auto-bump will be to 1.11.1

**Result:** Next release uses the manual version instead of auto-patch-bump

---

## Key Pipeline Resources

### Inputs

| Resource | Type | Purpose |
|----------|------|---------|
| `buildpack` | git | Buildpack source code (watches master branch) |
| `buildpacks-ci` | git | CI tasks and scripts |
| `version` | semver | Reads/writes VERSION file via git |

### Outputs

| Resource | Type | Purpose |
|----------|------|---------|
| `buildpack-github-release` | github-release | Creates GitHub releases |
| `pivotal-buildpack-{stack}` | s3 | Uncached buildpacks on S3 |
| `pivotal-buildpack-cached-{stack}` | s3 | Cached buildpacks on S3 |
| `version` | semver | Updates VERSION file after release |

### Version Resource (semver)

Special Concourse resource type that manages version in git:

```yaml
- name: version
  type: semver
  source:
    driver: git
    uri: git@github.com:cloudfoundry/go-buildpack.git
    branch: master
    file: VERSION
    private_key: ((ssh-key))
    commit_message: "[ci skip] bump to %version%"
```

**Operations:**
- `get: version` - Reads current version from VERSION file
- `put: version, params: {bump: patch}` - Increments patch version and commits

---

## Common Questions

**Q: When does the pipeline run?**  
A: Automatically on every commit to master. Unit tests, integration tests, and artifact building happen automatically. Only the `ship-it` job requires manual trigger.

**Q: Can I test changes before merging?**  
A: Yes! The pipeline also has a pull-request job that runs tests on PRs. Check your organization's Concourse for PR-specific pipelines.

**Q: What if tests fail?**  
A: The pipeline stops at the first failure. The `detect-new-version-and-upload-artifacts` job won't run if tests fail, and `ship-it` won't be available. Fix the issue and push another commit.

**Q: Can I skip tests?**  
A: No, and you shouldn't. Tests are there to catch regressions. If tests are flaky, fix the tests.

**Q: How do I see what changed since the last release?**  
A: Check the CHANGELOG file, or use git:
```bash
git log v1.10.48..HEAD --oneline
```

**Q: What if ship-it fails?**  
A: Common causes:
- Tag already exists on GitHub (check-tag-not-already-added fails)
- Invalid CHANGELOG format (finalize-buildpack fails)
- Network issues pushing to GitHub (buildpack-github-release fails)

Check the failing task's logs in Concourse for details.

**Q: Can I trigger a release from CLI?**  
A: Yes, using the `fly` CLI:
```bash
fly -t <target> trigger-job -j go-buildpack/ship-it
```

---

## Troubleshooting

### Ship-it Fails: "Tag already exists"

**Error:** `check-tag-not-already-added` task fails

**Cause:** The git tag (e.g., `v1.10.49`) already exists on GitHub

**Fix:**
```bash
# Check current VERSION
cat VERSION  # Shows 1.10.49

# Check if tag exists
git fetch --tags
git tag | grep v1.10.49

# If tag exists and no release was created, delete it:
git tag -d v1.10.49
git push origin :refs/tags/v1.10.49

# If release was already created, bump VERSION manually:
echo "1.10.50" > VERSION
git add VERSION
git commit -m "[ci skip] bump to 1.10.50"
git push origin master
```

### Integration Tests Fail for New Stack

**Error:** `specs-switchblade-docker-cflinuxfs6` fails

**Possible causes:**
- Stack image not available in Docker registry
- Dependencies incompatible with new stack's OS version
- Test fixtures need updating

**Fix:**
1. Check if stack image exists: `docker pull cloudfoundry/cflinuxfs6:latest`
2. Run tests locally with the new stack
3. Update manifest.yml to skip incompatible dependency versions
4. Add stack to dependency-builds pipeline first

### Artifacts Missing from S3

**Error:** `detect-new-version-and-upload-artifacts` succeeds but ship-it can't find artifacts

**Cause:** S3 upload failed or bucket permissions issue

**Fix:**
1. Check S3 bucket: `aws s3 ls s3://pivotal-buildpacks/go/`
2. Verify IAM permissions for Concourse service account
3. Re-run `detect-new-version-and-upload-artifacts` job manually

---

## Best Practices

### Before Triggering Ship-It

✅ **Checklist:**
1. All Concourse jobs are green
2. Review CHANGELOG - latest entry is accurate
3. Check recent commits - all changes ready to release
4. Verify no breaking changes (or version is bumped appropriately)
5. Check if any PRs should be merged before releasing

### After Release

✅ **Post-release checklist:**
1. Verify GitHub release appears correctly
2. Download and test at least one artifact (smoke test)
3. Check buildpack-release pipeline (BOSH releases) triggers automatically
4. Announce release in #buildpacks Slack channel (if significant)
5. Update any dependent documentation

### Communication

**When to announce releases:**
- ✅ Major or minor version bumps (1.11.0)
- ✅ EOL runtime removals
- ✅ Breaking changes
- ✅ Critical security fixes
- ❌ Routine patch versions (1.10.49 → 1.10.50)

---

## Next Steps

1. **Watch a release happen:** Ask to observe when a maintainer triggers ship-it
2. **Read the pipeline YAML:** `pipelines/buildpack/pipeline.yml`
3. **Understand tasks:** Review `tasks/finalize-buildpack/` and `tasks/detect-and-upload/`
4. **Ask questions:** #buildpacks Slack channel

Welcome to the buildpack release process! 🎉
