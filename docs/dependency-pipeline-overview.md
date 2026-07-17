# Dependency Pipeline Overview

## What is the Dependency Pipeline?

The dependency pipeline is an **automated CI/CD system** that keeps Cloud Foundry buildpacks up-to-date with the latest runtime and tool versions. It continuously monitors upstream sources (like GitHub, npm, PyPI, etc.) for new releases, builds them for supported stacks, and automatically opens pull requests to update buildpack manifests.

**Think of it as:** A robot that watches for new versions of Go, Node.js, Ruby, Python, Java, and other tools, compiles them for Cloud Foundry, and proposes updates to the buildpacks that use them.

---

## Why Do We Need It?

### With the Dependency Pipeline
- ✅ **Automated discovery**: Detects new versions within minutes
- ✅ **Automated builds**: Compiles binaries for all stacks automatically
- ✅ **Automated PRs**: Opens pull requests with updated manifests
- ✅ **Automated testing**: Runs integration tests before merging
- ✅ **EOL tracking**: Warns about approaching deprecation dates

**Result:** Buildpacks stay current with minimal manual effort.

---

## How It Works (Simple Overview)

```
┌──────────────────┐
│  Upstream Source │  (GitHub, PyPI, npm, etc.)
│  New version!    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Depwatcher      │  Monitors upstream sources every 15 min
│  (Detection)     │  Detects: "Go 1.26.6 released!"
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Build Binary    │  Compiles for each stack:
│  (Compilation)   │  - cflinuxfs4
└────────┬─────────┤  - cflinuxfs5
         │         │  Uploads to S3
         ▼         │
┌──────────────────┐
│  Update Manifest │  Creates PR to buildpack repo:
│  (PR Creation)   │  - Adds Go 1.26.6
└────────┬─────────┤  - Removes Go 1.26.4 (old patch)
         │         │  - Updates SHA256 checksums
         ▼         │
┌──────────────────┐
│  Run Tests       │  Integration tests run automatically
│  (Validation)    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Merge PR        │  Maintainer reviews and merges
│  (Manual Step)   │
└──────────────────┘
```

---

## Key Concepts

### 1. **Dependencies**
Runtime languages and tools that buildpacks include:
- **Runtimes:** Go, Node.js, Ruby, Python, PHP, Java (OpenJDK, Zulu, etc.)
- **Tools:** bundler, yarn, pip, composer, godep, glide
- **Agents:** AppDynamics, New Relic, Datadog, OpenTelemetry

### 2. **Stacks**
Base operating system images that apps run on:
- **cflinuxfs4** - Ubuntu 22.04 (Jammy)
- **cflinuxfs5** - Ubuntu 24.04 (Noble)

Most dependencies need to be compiled separately for each stack because they link to different OS libraries.

### 3. **Version Lines**
Patterns that specify which versions to track:
- `1.26.X` - Track all patches of Go 1.26 (1.26.1, 1.26.2, etc.)
- `22.X.X` - Track all Node.js 22.x releases
- `latest` - Always track the single latest version
- `node-lts` - Special named line for Node.js LTS

### 4. **Manifest.yml**
The file in each buildpack that lists available dependency versions:
```yaml
- name: go
  version: 1.26.5
  uri: https://buildpacks.cloudfoundry.org/dependencies/go/go_1.26.5_linux_x64_cflinuxfs4.tgz
  sha256: a9eea5cbd6da4fc2f18b9cd6af1ef9cb43a3803b253cc802366afeac00e3be67
  cf_stacks:
  - cflinuxfs4
```

---

## Configuration: config.yml

The pipeline is driven by a single configuration file: `pipelines/dependency-builds/config.yml`

### Example: Adding Go Versions to go-buildpack

```yaml
dependencies:
  go:
    buildpacks:
      go:
        lines:
          - line: 1.25.X                    # Track all Go 1.25 patches
            deprecation_date: ""            # No EOL date yet
            link: https://golang.org/doc/devel/release.html
          - line: 1.26.X                    # Track all Go 1.26 patches
            deprecation_date: ""
            link: https://golang.org/doc/devel/release.html
        removal_strategy: remove_all        # Remove old patches when new ones arrive
    versions_to_keep: 1                     # Keep only the latest patch per line
```

**What this does:**
- Monitors Go releases for versions 1.25.x and 1.26.x
- When Go 1.26.6 is released, builds it for all stacks
- Opens PR to go-buildpack: Add 1.26.6, remove 1.26.5
- Links to Go's EOL policy page

---

## Common Operations

### Adding a New Dependency Version Line

**Scenario:** Go 1.27 is released, we need to start tracking it.

**Steps:**
1. Edit `pipelines/dependency-builds/config.yml`
2. Add new line under `go.buildpacks.go.lines`:
   ```yaml
   - line: 1.27.X
     deprecation_date: ""
     link: https://golang.org/doc/devel/release.html
   ```
3. Deploy pipeline: `./bin/update-pipelines -p dependency-builds`
4. Pipeline automatically builds Go 1.27.x versions and opens PRs

### Removing an EOL Version Line

**Scenario:** Go 1.24 reached EOL, stop building it.

**Steps:**
1. Edit `pipelines/dependency-builds/config.yml`
2. Remove the `1.24.X` line from `go.buildpacks.go.lines`
3. Deploy pipeline: `./bin/update-pipelines -p dependency-builds`
4. Pipeline stops monitoring/building Go 1.24
5. **Note:** Existing 1.24 versions in buildpack manifests must be manually removed via PR

### Adding a New Stack (e.g., cflinuxfs6)

**Steps:**
1. Add to `build_stacks` in `config.yml`:
   ```yaml
   build_stacks: ['cflinuxfs4', 'cflinuxfs5', 'cflinuxfs6']
   ```
2. Deploy pipeline: `./bin/update-pipelines -p dependency-builds`
3. All dependencies automatically build for the new stack
4. If a dependency is incompatible, add to its `skip_lines`:
   ```yaml
   skip_lines:
     cflinuxfs6: ['3.0.X']  # Ruby 3.0 doesn't work on cflinuxfs6
   ```

---

## Typical Workflow

### For Routine Version Updates (Automated)

1. ⏰ **Every 15 minutes:** Depwatcher checks upstream sources
2. 🆕 **New version detected:** "Go 1.26.6 released!"
3. 🔨 **Build jobs trigger:** Compiles for cflinuxfs4 and cflinuxfs5
4. 📦 **Uploads to S3:** Binary tarballs stored
5. 🤖 **Bot opens PR:** "Add go 1.26.6, remove go 1.26.5"
6. ✅ **Tests run:** Integration tests validate the new version
7. 👤 **Maintainer reviews:** Checks PR, merges if tests pass

#### ⚠️ Important: PR Review Checklist

**Known Issue - Incomplete Old Version Removal:**

The automated PRs sometimes have an issue where old versions are **not removed from all stacks**. When reviewing PRs:

✅ **Check that new versions are added for ALL active stacks:**
```yaml
# New version should be present for all stacks:
- name: go
  version: 1.26.6
  cf_stacks: [cflinuxfs4]    # ✓ cflinuxfs4
  
- name: go
  version: 1.26.6
  cf_stacks: [cflinuxfs5]    # ✓ cflinuxfs5
```

⚠️ **Check that old versions are removed from ALL stacks:**
```yaml
# OLD VERSION - Should be removed from BOTH stacks, but PR might only remove one:
- name: go
  version: 1.26.5
  cf_stacks: [cflinuxfs4]    # ❌ Still present - SHOULD BE REMOVED
  
# If the old version remains for any stack, manually edit the PR to remove it
```

**Before merging:**
1. Verify new version added for **all active stacks** (currently cflinuxfs4, cflinuxfs5)
2. Verify old version removed from **all active stacks** (not just one)
3. If old version remains for any stack, edit the PR or add a commit to remove it
4. Check that SHA256 checksums are present and look valid

This prevents buildpack manifests from accumulating stale versions on some stacks while being clean on others.

### For EOL Version Removal (Manual)

1. 📅 **EOL date reached:** Go 1.24 is no longer supported
2. 👤 **Maintainer updates config.yml:** Removes `1.24.X` line
3. 🚀 **Deploy pipeline:** `./bin/update-pipelines`
4. 🛑 **Pipeline stops building 1.24**
5. 👤 **Maintainer creates PR:** Removes 1.24 entries from manifest.yml
6. 🔖 **Version bump (optional):** If breaking change, bump minor version
7. 📢 **Communication:** Announce to users via release notes

---

## Key Files and Directories

```
buildpacks-ci/
├── pipelines/
│   └── dependency-builds/
│       ├── config.yml          # Main configuration (what to build)
│       ├── pipeline.yml        # Pipeline template (how to build)
│       └── README.md           # Detailed reference documentation
├── tasks/
│   ├── build-binary/           # Compiles dependency for a stack
│   ├── update-buildpack-manifest/  # Creates PR with manifest changes
│   └── check-for-latest-dependency-versions/  # Monitors depwatcher
└── bin/
    └── update-pipelines        # Deploys pipeline changes to Concourse
```

---

## Common Questions

**Q: What if a build fails?**  
A: Build failures are visible in the Concourse dashboard as red jobs. Maintainers can:
- Click on the failed job to view logs
- Check if it's a transient issue (retry the build manually)
- Investigate build logs for missing dependencies or upstream issues
- Fix the issue (usually missing OS packages, upstream source changes, or build script updates)

Concourse does not automatically retry failed builds - maintainers must manually trigger a retry or fix the underlying issue.

**Q: How do I monitor for build failures?**  
A: Regularly check the Concourse dashboard. Failed jobs appear in red. You can also:
- Subscribe to buildpack repositories to get PR notifications (successful builds create PRs)
- Periodically review the dependency-builds pipeline for any red/failed jobs

**Q: Can I test a dependency locally before it goes to production?**  
A: Yes! Use the `build-binary` task with the same inputs the pipeline uses. You can run it locally with Docker or in a test Concourse instance.

**Q: How do I know when a dependency is approaching EOL?**  
A: The pipeline tracks EOL dates through the `deprecation_date` field in config.yml:

1. **In config.yml:** Set the `deprecation_date` for each version line:
   ```yaml
   - line: 1.25.X
     deprecation_date: 2027-08-12
     link: https://golang.org/doc/devel/release.html
   ```

2. **Automated warning (if configured):** There's a task (`generate-dependency-deprecation-github-issue`) that can create GitHub issues **30 days before** the deprecation date with:
   - Issue title: "Deprecation: [buildpack-name] dependency version X.Y after YYYY-MM-DD"
   - Checklist for maintainers to confirm or update the date
   - Automatic addition to project board (if configured)
   
3. **Manual monitoring:** Even without automation:
   - Review `deprecation_date` fields in config.yml periodically
   - Set calendar reminders for important EOL dates
   - Watch upstream project announcements

**Q: What if I need a one-off version that doesn't fit a line pattern?**  
A: Add a specific line (e.g., `1.26.6`) instead of a wildcard pattern (e.g., `1.26.X`). The pipeline will only track that exact version.

**Q: Do I need to understand Concourse to maintain this?**  
A: Basic Concourse knowledge helps, but most work is editing `config.yml`. The detailed reference documentation is in `pipelines/dependency-builds/README.md` which has examples for common operations. Understanding Concourse concepts like resources, jobs, and tasks will help with troubleshooting, but day-to-day maintenance is mostly configuration changes.

---

## Getting Started

### Prerequisites
- Access to the buildpacks-ci repository
- Concourse access to **buildpacks-team** (to view pipelines)
- GitHub permissions (to merge PRs)

### Your First Change

**Try adding a new Go version line:**

1. Clone buildpacks-ci: `git clone https://github.com/cloudfoundry/buildpacks-ci`
2. Edit `pipelines/dependency-builds/config.yml`
3. Find the `go` dependency, add a new line
4. Test locally: `./bin/update-pipelines -p dependency-builds -t` (dry-run)
5. Deploy: `./bin/update-pipelines -p dependency-builds`
6. Watch in Concourse as new jobs appear

### Learning Resources

- **Detailed Reference:** `pipelines/dependency-builds/README.md`
- **Example PRs:** Search for "pr-by-releng-bot" in buildpack repos
- **Slack:** #buildpacks channel for questions
- **Concourse Dashboard:** View pipeline execution in real-time

---

## Troubleshooting Tips

### PR Not Created After Build
- Check if `versions_to_keep` limit is reached
- Check if the version already exists in manifest
- Check build job logs for errors

### Too Many Versions in Manifest
- Increase `versions_to_keep`
- Check `removal_strategy` setting

---

**For new maintainers:** Start by reviewing automated PRs, then gradually learn to configure version lines and handle EOL removals. The pipeline does the heavy lifting—you provide the oversight.

---

## Next Steps

1. **Read the detailed reference:** `pipelines/dependency-builds/README.md`
2. **Watch the pipeline:** https://buildpacks.ci.cf-app.com/teams/main/pipelines/dependency-builds
3. **Review a few automated PRs** in buildpack repositories
4. **Try a small config change** (add a version line, update an EOL date)
5. **Ask questions** in #buildpacks Slack channel

Welcome to the buildpacks maintainer community! 🎉
