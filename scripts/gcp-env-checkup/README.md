# GCP Buildpack Environment Checkup Tool

Detects orphaned GCP buildpack environments (VPC networks) that are not part of running Concourse jobs and provides interactive cleanup functionality.

## Overview

This tool helps identify buildpack environments in GCP that may have been left running after integration tests complete. It checks:

1. **GCP VPC Networks**: Lists all networks matching the buildpack pattern (`%LANGUAGE%-buildpack-bbl-env-network`)
2. **Concourse Jobs**: Verifies if corresponding integration test jobs are currently running
3. **GitHub State**: Checks if the buildpacks-envs repository state directories are empty

An environment is considered **orphaned** when:
- The VPC network exists in GCP
- The Concourse integration test job is NOT running

The state directory status is checked and reported for informational purposes to help understand whether the environment was intentionally left or accidentally orphaned.

### Features

- ✅ **Automatic Discovery**: Finds all buildpack VPC networks automatically
- ✅ **Multi-Source Validation**: Cross-checks GCP, Concourse, and GitHub
- ✅ **Interactive Cleanup**: Safely destroy orphaned environments with user confirmation
- ✅ **Color-Coded Output**: Easy-to-read reports with visual indicators (red for orphaned, green for healthy)
- ✅ **Dual Output Formats**: Human-readable text or machine-parseable JSON
- ✅ **Comprehensive Checks**: Validates dependencies and authentication before running
- ✅ **Configurable**: All settings controllable via environment variables
- ✅ **CI/CD Friendly**: Non-zero exit code when orphaned environments found

## Prerequisites

### Required CLI Tools

#### Check Mode

This tool requires the following command-line tools to be installed and available in your PATH:

1. **gcloud** - Google Cloud SDK
   - Installation: https://cloud.google.com/sdk/docs/install
   - Used for listing GCP VPC networks

2. **fly** - Concourse CLI
   - Installation: https://concourse-ci.org/download.html
   - Used for checking Concourse job status

3. **gh** - GitHub CLI
   - Installation: https://cli.github.com/
   - Used for checking buildpacks-envs repository state

4. **jq** - JSON processor
   - Installation: https://stedolan.github.io/jq/download/
   - Used for parsing JSON responses

#### Cleanup Mode (Additional Requirements)

When running in cleanup mode (`--cleanup`), these additional tools are required:

5. **bbl** - BOSH Bootloader
   - Installation: https://github.com/cloudfoundry/bosh-bootloader
   - Used for destroying BBL environments

6. **bosh** - BOSH CLI
   - Installation: https://bosh.io/docs/cli-v2-install/
   - Used for managing BOSH deployments

7. **git** - Git version control
   - Installation: https://git-scm.com/downloads
   - Used for cloning/updating buildpacks-envs repository

8. **leftovers** - GCP resource cleanup tool
   - Installation: https://github.com/genevieve/leftovers
   - Used as fallback "nuclear option" when BBL destroy fails
   - Filters and deletes all GCP resources matching the environment name

The script will validate all dependencies before execution and report any missing tools.

### Authentication

You must be authenticated with all three services before running the tool:

#### 1. GCP Authentication

```bash
# Standard user authentication
gcloud auth login

# Or service account authentication
gcloud auth activate-service-account --key-file=KEY_FILE.json

# Set active project
gcloud config set project app-runtime-interfaces-wg
```

#### 2. Concourse Authentication

```bash
# Login to Concourse (interactive)
fly -t buildpacks login \
    -c https://concourse.app-runtime-interfaces.ci.cloudfoundry.org \
    -n buildpacks-team

# Or with credentials
fly -t buildpacks login \
    -c https://concourse.app-runtime-interfaces.ci.cloudfoundry.org \
    -n buildpacks-team \
    -u USERNAME -p PASSWORD

# Verify authentication
fly -t buildpacks status
```

#### 3. GitHub Authentication

```bash
# Interactive authentication
gh auth login

# Or with token
echo $GITHUB_TOKEN | gh auth login --with-token

# Verify authentication
gh auth status
```

## Usage

### Command-Line Options

```bash
# Show help
./scripts/gcp-env-checkup/check.sh --help

# Check for orphaned environments (default mode)
./scripts/gcp-env-checkup/check.sh
./scripts/gcp-env-checkup/check.sh --check-only

# Interactive cleanup mode
./scripts/gcp-env-checkup/check.sh --cleanup
```

### Basic Usage

#### Check Mode (Default)

```bash
# Run check with default settings
./scripts/gcp-env-checkup/check.sh
```

This will:
1. List all buildpack VPC networks in GCP
2. Check if corresponding Concourse jobs are running
3. Check GitHub state directory status
4. Report which environments are orphaned
5. Exit with code 1 if orphaned environments are found

#### Cleanup Mode

```bash
# Interactive cleanup of orphaned environments
export GCP_SERVICE_ACCOUNT_KEY="/path/to/service-account-key.json"
./scripts/gcp-env-checkup/check.sh --cleanup
```

This will:
1. Perform all check mode operations
2. Display orphaned environments
3. Prompt you to select which environments to clean up:
   - Enter specific numbers (e.g., `1,3,5`)
   - Enter `a` to select all orphaned environments
   - Enter `c` to cancel
4. Show summary and ask for final confirmation
5. For each selected environment:
   - Clone/update buildpacks-envs repository
   - Load BBL environment variables
   - Delete all BOSH deployments
   - Run BOSH cleanup
   - Destroy BBL environment (VPC, instances, etc.)

**⚠️ WARNING**: Cleanup is irreversible! Double-check before confirming.

### Configuration

The tool can be configured using environment variables:

| Variable | Description | Default | Required For |
|----------|-------------|---------|--------------|
| `GCP_PROJECT` | GCP project ID | `app-runtime-interfaces-wg` | All modes |
| `CONCOURSE_URL` | Concourse URL | `https://concourse.app-runtime-interfaces.ci.cloudfoundry.org` | All modes |
| `CONCOURSE_TEAM` | Concourse team name | `buildpacks-team` | All modes |
| `CONCOURSE_TARGET` | Fly target name | `buildpacks` | All modes |
| `GITHUB_REPO` | GitHub repository | `cloudfoundry/buildpacks-envs` | All modes |
| `GCP_SERVICE_ACCOUNT_KEY` | Path to GCP service account key file | (none) | **Cleanup mode only** |
| `OUTPUT_FORMAT` | Output format (`text` or `json`) | `text` | All modes |
| `DEBUG` | Enable debug mode (`true` or `false`) | `false` | All modes |
| `NO_COLOR` | Disable colored output (`true` or `false`) | `false` | All modes |

### Examples

#### Check Mode Examples

##### Custom GCP Project

```bash
GCP_PROJECT="my-project" ./scripts/gcp-env-checkup/check.sh
```

##### JSON Output

```bash
OUTPUT_FORMAT=json ./scripts/gcp-env-checkup/check.sh
```

##### Debug Mode

```bash
DEBUG=true ./scripts/gcp-env-checkup/check.sh
```

##### Disable Colors

```bash
# Useful for piping to files or when colors aren't supported
NO_COLOR=true ./scripts/gcp-env-checkup/check.sh
```

##### Full Custom Configuration

```bash
GCP_PROJECT="my-project" \
CONCOURSE_URL="https://my-concourse.example.com" \
CONCOURSE_TEAM="my-team" \
CONCOURSE_TARGET="my-target" \
OUTPUT_FORMAT=json \
./scripts/gcp-env-checkup/check.sh
```

#### Cleanup Mode Examples

##### Basic Cleanup

```bash
export GCP_SERVICE_ACCOUNT_KEY="$HOME/.gcp/service-account-key.json"
./scripts/gcp-env-checkup/check.sh --cleanup
```

##### Cleanup with Debug Mode

```bash
export GCP_SERVICE_ACCOUNT_KEY="$HOME/.gcp/service-account-key.json"
DEBUG=true ./scripts/gcp-env-checkup/check.sh --cleanup
```

##### Cleanup with Custom Configuration

```bash
export GCP_SERVICE_ACCOUNT_KEY="$HOME/.gcp/service-account-key.json"
GCP_PROJECT="my-project" \
CONCOURSE_TARGET="my-target" \
./scripts/gcp-env-checkup/check.sh --cleanup
```

## Output

### Text Format (Default)

The default text output provides a clear, color-coded summary and detailed breakdown:

**Color Scheme:**
- 🔴 **Red**: Orphaned environments and critical issues
- 🟢 **Green**: Healthy environments and success messages
- 🟡 **Yellow**: Warnings and inactive jobs
- 🔵 **Blue**: Section headers
- 🟦 **Cyan**: Informational metadata
- **Bold**: Main headers

**Example Output:**

```
======================================
GCP Buildpack Environment Checkup
======================================

GCP Project: app-runtime-interfaces-wg
Concourse: https://concourse.app-runtime-interfaces.ci.cloudfoundry.org
GitHub Repo: cloudfoundry/buildpacks-envs

⚠ Found 3 orphaned environment(s)

All Environments:
-------------------------------------
  • java (java-buildpack/create-cf-infrastructure-and-execute-integration-test-for-java-cflinuxfs4)
    Network: java-buildpack-bbl-env-network
    Job Running: No
    State Empty: No
    Orphaned: YES ⚠

  • go (go-buildpack/create-cf-infrastructure-and-execute-integration-test-for-go-cflinuxfs4)
    Network: go-buildpack-bbl-env-network
    Job Running: Yes
    State Empty: No
    Orphaned: No

  • releases (cf-release/deploy)
    Network: releases-buildpack-bbl-env-network
    Job Running: No
    State Empty: No
    Orphaned: YES ⚠
```

**When no orphaned environments:**
```
======================================
GCP Buildpack Environment Checkup
======================================

GCP Project: app-runtime-interfaces-wg
Concourse: https://concourse.app-runtime-interfaces.ci.cloudfoundry.org
GitHub Repo: cloudfoundry/buildpacks-envs

✓ No orphaned environments found
```

### JSON Format

For programmatic processing, use JSON output:

```bash
OUTPUT_FORMAT=json ./scripts/gcp-env-checkup/check.sh
```

Example JSON output:

```json
[
  {
    "network": "binary-buildpack-bbl-env-network",
    "identifier": "binary",
    "pipeline": "binary-buildpack",
    "job": "create-cf-infrastructure-and-execute-integration-test-for-binary-cflinuxfs4",
    "concourse_job_running": false,
    "state_directory_empty": true,
    "is_orphaned": true
  },
  {
    "network": "go-buildpack-bbl-env-network",
    "identifier": "go",
    "pipeline": "go-buildpack",
    "job": "create-cf-infrastructure-and-execute-integration-test-for-go-cflinuxfs4",
    "concourse_job_running": true,
    "state_directory_empty": false,
    "is_orphaned": false
  },
  {
    "network": "releases-buildpack-bbl-env-network",
    "identifier": "releases",
    "pipeline": "cf-release",
    "job": "deploy",
    "concourse_job_running": false,
    "state_directory_empty": true,
    "is_orphaned": true
  }
]
```

## Exit Codes

### Check Mode
- **0**: Success, no orphaned environments found
- **1**: Orphaned environments found OR dependency/authentication error

### Cleanup Mode
- **0**: Success, all selected environments cleaned up
- **1**: Cleanup error occurred OR user cancelled

## Interactive Cleanup Workflow

When running in cleanup mode (`--cleanup`), the tool provides an interactive workflow:

### 1. Check Phase
First performs all standard checks and displays the report with orphaned environments.

### 2. Selection Menu
Presents a numbered list of orphaned environments:
```
======================================
Select Environments for Cleanup
======================================

  1. java (java-buildpack-bbl-env-network)
  2. releases (releases-buildpack-bbl-env-network)
  3. ruby (ruby-buildpack-bbl-env-network)

  a. All orphaned environments
  c. Cancel

Select environments (comma-separated numbers, 'a' for all, or 'c' to cancel):
```

**Selection options:**
- Enter specific numbers: `1,3` (comma-separated)
- Enter `a` to select all orphaned environments
- Enter `c` to cancel

### 3. Confirmation
Shows a summary of what will be deleted and asks for final confirmation:
```
======================================
Cleanup Summary
======================================

The following environments will be deleted:

  • java (java-buildpack-bbl-env-network)
  • ruby (ruby-buildpack-bbl-env-network)

This will:
  1. Delete all BOSH deployments in each environment
  2. Run BOSH cleanup
  3. Destroy the BBL environment (VPC, instances, etc.)

⚠ WARNING: This action is IRREVERSIBLE!

Are you sure you want to proceed? (yes/no):
```

**You must type `yes` exactly to proceed.** Any other input cancels the operation.

### 4. Cleanup Execution
For each selected environment, the tool:

1. **Clones/updates buildpacks-envs repository** into `.cache/buildpacks-envs/`
2. **Enters state directory**: `cd buildpacks-envs/{identifier}-buildpack-state`
3. **Loads BBL environment**: `eval "$(bbl print-env)"`
4. **Lists BOSH deployments**: `bosh deployments` (skipped if BOSH director unreachable)
5. **Deletes each deployment**: `bosh delete-deployment -d <name> -n` (best-effort, continues on failure)
6. **Cleans up BOSH**: `bosh clean-up --all -n` (best-effort, continues on failure)
7. **Destroys BBL environment**: `bbl destroy --iaas gcp --gcp-service-account-key $GCP_SERVICE_ACCOUNT_KEY -n`
8. **Nuclear fallback (if BBL destroy fails)**: `leftovers --iaas gcp --gcp-service-account-key $GCP_SERVICE_ACCOUNT_KEY --no-confirm --filter {network-name}`

**Note**: BOSH operations (steps 4-6) are best-effort. If the BOSH director is unreachable (common for orphaned environments), these steps are skipped or warned, and the script proceeds to BBL destroy.

### 5. Error Handling and Fallback Strategy

**Best-Effort Operations** (warn and continue):
- BOSH director unreachable → Skip BOSH operations
- BOSH deployment deletion fails → Warn and continue
- BOSH cleanup fails → Warn and continue

**Critical Operations** (stop on failure):
- State directory missing → Stop (cannot proceed)
- BBL environment load fails → Stop (invalid state)
- GCP service account key issues → Stop (cannot authenticate)

**Nuclear Fallback**:
- If BBL destroy fails, automatically falls back to `leftovers`
- `leftovers` uses a filter to match the network name and deletes ALL matching GCP resources
- This is more aggressive and ensures cleanup even when BBL state is corrupted
- If both BBL destroy AND leftovers fail → Stop and report (manual cleanup required)

### Example Session
```bash
$ export GCP_SERVICE_ACCOUNT_KEY="$HOME/.gcp/service-account-key.json"
$ ./scripts/gcp-env-checkup/check.sh --cleanup

Checking dependencies...
Verifying authentication...
Discovering buildpack VPC networks...
Found 5 buildpack network(s). Analyzing...

======================================
GCP Buildpack Environment Checkup
======================================

⚠ Found 2 orphaned environment(s)

All Environments:
-------------------------------------
  • java (java-buildpack/...)
    Orphaned: YES ⚠

  • ruby (ruby-buildpack/...)
    Orphaned: YES ⚠

  • go (go-buildpack/...)
    Orphaned: No

======================================
Select Environments for Cleanup
======================================

  1. java (java-buildpack-bbl-env-network)
  2. ruby (ruby-buildpack-bbl-env-network)

  a. All orphaned environments
  c. Cancel

Select environments: 1,2

======================================
Cleanup Summary
======================================

The following environments will be deleted:
  • java (java-buildpack-bbl-env-network)
  • ruby (ruby-buildpack-bbl-env-network)

⚠ WARNING: This action is IRREVERSIBLE!

Are you sure you want to proceed? (yes/no): yes

Cloning buildpacks-envs repository...

======================================
Cleaning up: java
======================================

→ Entering state directory...
→ Loading BBL environment...
→ Listing BOSH deployments...
→ Deleting BOSH deployment: cf...
→ Running BOSH cleanup...
→ Destroying BBL environment...
✓ Successfully cleaned up java

======================================
Cleaning up: ruby
======================================

→ Entering state directory...
→ Loading BBL environment...
→ Listing BOSH deployments...
  No BOSH deployments to delete
→ Running BOSH cleanup...
→ Destroying BBL environment...
✓ Successfully cleaned up ruby

======================================
All selected environments cleaned up successfully!
======================================
```

## How It Works

### Check Mode

#### 1. Dependency Check

Validates that all required CLI tools are installed:
- Check mode: `gcloud`, `fly`, `gh`, `jq`
- Cleanup mode: Additional tools: `bbl`, `bosh`, `git`

#### 2. Authentication Verification

Checks that you're authenticated with:
- GCP (gcloud)
- Concourse (fly)
- GitHub (gh)

#### 3. VPC Network Discovery

Lists all VPC networks in the GCP project matching the pattern:
```
*-buildpack-bbl-env-network
```

Examples:
- `binary-buildpack-bbl-env-network`
- `go-buildpack-bbl-env-network`
- `nodejs-buildpack-bbl-env-network`

### 4. Concourse Job Check

For each discovered network, checks if the corresponding Concourse job is running.

**For standard buildpack environments:**
```
Pipeline: {identifier}-buildpack
Job: create-cf-infrastructure-and-execute-integration-test-for-{identifier}-cflinuxfs4
```

Example:
- Network: `binary-buildpack-bbl-env-network`
- Pipeline: `binary-buildpack`
- Job: `create-cf-infrastructure-and-execute-integration-test-for-binary-cflinuxfs4`

**For cf-release environment (special case):**
```
Pipeline: cf-release
Job: deploy
```

Example:
- Network: `releases-buildpack-bbl-env-network`
- Pipeline: `cf-release`
- Job: `deploy`

#### 5. GitHub State Check

Checks the buildpacks-envs repository for state directories:
```
{identifier}-buildpack-state/
```

Examples:
- `binary-buildpack-state/`
- `releases-buildpack-state/` (for cf-release pipeline)

A directory is considered "empty" (meaning the environment is not actively managed) if:
- The directory doesn't exist
- The directory is empty
- The directory only contains `terraform/.terraform.lock.hcl`

#### 6. Orphan Detection

An environment is flagged as **orphaned** when:
- ✅ VPC network exists in GCP
- ✅ Concourse integration test job is **NOT running**

The state directory check is performed and reported for informational purposes, but an environment is considered orphaned if it's consuming GCP resources (VPC network exists) without an active Concourse job, regardless of whether state files exist in the buildpacks-envs repository.

### Cleanup Mode (Additional Steps)

When running with `--cleanup` flag:

#### 7. Repository Setup
Clones or updates the buildpacks-envs repository into `.cache/buildpacks-envs/`:
- First run: Clones fresh copy
- Subsequent runs: Updates existing copy with `git pull`
- Cache location: `scripts/gcp-env-checkup/.cache/` (excluded from git)

#### 8. BBL Environment Loading
For each environment to be cleaned:
- Changes to state directory: `{identifier}-buildpack-state`
- Loads BBL environment variables: `eval "$(bbl print-env)"`
- This sets up BOSH CLI to target the environment's director

#### 9. BOSH Deployment Deletion (Best-Effort)
- Lists all deployments: `bosh deployments`
- If BOSH director unreachable: Skips BOSH operations (director may be down)
- Deletes each deployment: `bosh delete-deployment -d <name> -n`
- Runs cleanup: `bosh clean-up --all -n`
- All failures in this step are warnings, not errors

#### 10. BBL Infrastructure Destruction
Destroys the entire BBL environment:
- Uses GCP service account key for authentication
- Deletes BOSH director, VPC network, firewall rules, load balancers, VMs, etc.
- Command: `bbl destroy --iaas gcp --gcp-service-account-key $GCP_SERVICE_ACCOUNT_KEY -n`

#### 11. Nuclear Fallback (Leftovers)
If BBL destroy fails (corrupted state, partial deletion, etc.):
- Automatically invokes `leftovers` as last resort
- Uses network name as filter: `--filter {network-name}`
- Scans and deletes ALL GCP resources matching the filter
- More aggressive than BBL destroy (doesn't rely on state files)
- Command: `leftovers --iaas gcp --gcp-service-account-key $GCP_SERVICE_ACCOUNT_KEY --no-confirm --filter {network-name}`

## Troubleshooting

### "Missing required dependencies"

**Problem**: One or more CLI tools are not installed.

**Solution**: Install the missing tools:
- gcloud: https://cloud.google.com/sdk/docs/install
- fly: Download from your Concourse instance or https://concourse-ci.org/download.html
- gh: https://cli.github.com/
- jq: `brew install jq` (macOS) or `apt-get install jq` (Linux)

### "gcloud not authenticated"

**Problem**: Not logged in to GCP.

**Solution**:
```bash
gcloud auth login
gcloud config set project app-runtime-interfaces-wg
```

### "fly not authenticated"

**Problem**: Not logged in to Concourse or token expired.

**Solution**:
```bash
fly -t buildpacks login \
    -c https://concourse.app-runtime-interfaces.ci.cloudfoundry.org \
    -n buildpacks-team
```

### "gh not authenticated"

**Problem**: Not logged in to GitHub.

**Solution**:
```bash
gh auth login
```

### "No buildpack networks found"

**Problem**: No VPC networks matching the buildpack pattern exist in the GCP project.

**Possible causes**:
- Wrong GCP project (check with `gcloud config get-value project`)
- No buildpack environments currently exist
- Insufficient permissions to list networks

**Solution**: Verify the project and your permissions.

### "404 Not Found" errors from gh

**Problem**: buildpacks-envs repository or directories don't exist.

**Possible causes**:
- Wrong repository name
- Directory structure changed
- Insufficient GitHub permissions

**Solution**: Verify repository access and structure.

### Cleanup Mode Issues

#### "GCP_SERVICE_ACCOUNT_KEY environment variable not set"

**Problem**: Required environment variable for cleanup not configured.

**Solution**:
```bash
export GCP_SERVICE_ACCOUNT_KEY="/path/to/service-account-key.json"
```

#### "GCP service account key file not found"

**Problem**: Path in GCP_SERVICE_ACCOUNT_KEY doesn't exist.

**Solution**: Verify the file path:
```bash
ls -l "$GCP_SERVICE_ACCOUNT_KEY"
```

#### "Failed to load BBL environment"

**Problem**: State directory is corrupted or BBL state is invalid.

**Possible causes**:
- State directory is incomplete
- BBL version mismatch
- Corrupted state files

**Solution**: Manual investigation required. Check the state directory contents.

#### "Failed to clone buildpacks-envs repository"

**Problem**: Cannot access GitHub repository.

**Possible causes**:
- No internet connection
- GitHub authentication expired
- Insufficient permissions

**Solution**: Verify GitHub access:
```bash
gh auth status
git ls-remote https://github.com/cloudfoundry/buildpacks-envs.git
```

#### Cleanup stopped mid-process

**Problem**: Cleanup failed partway through an environment.

**Impact**: Environment may be partially destroyed (some resources deleted, others remain).

**Solution**: 
1. Check error message for specific failure point
2. May need manual cleanup in GCP console
3. Check BBL state directory for remaining state
4. Can try re-running cleanup for that environment

## Architecture

The tool is built with modular, functional design principles:

### Pure Functions
Each check (network discovery, job status, state check) is a pure function that:
- Takes explicit inputs
- Returns predictable outputs
- Has no side effects
- Is independently testable

### Modular Components

#### Check Mode Functions
1. **Dependency Checker**: Validates CLI tools (with mode-specific requirements)
2. **Authentication Checker**: Verifies service authentication
3. **Network Discovery**: Lists GCP VPC networks
4. **Job Status Checker**: Checks Concourse job status
5. **State Checker**: Verifies GitHub repository state
6. **Reporter**: Generates human-readable or JSON output

#### Cleanup Mode Functions
7. **Repository Manager**: Clones/updates buildpacks-envs repository
8. **Environment Selector**: Interactive menu for selecting environments
9. **Environment Cleaner**: Executes cleanup sequence (BOSH + BBL)

### Error Handling

- Fails fast on missing dependencies or authentication
- Uses `set -o errexit -o nounset -o pipefail` for robust error handling
- Provides clear error messages with remediation steps

## Known Buildpacks

The tool automatically discovers buildpack environments. Known environments include:

**Standard Buildpacks:**
- binary-buildpack
- go-buildpack
- nodejs-buildpack
- python-buildpack
- java-buildpack
- php-buildpack
- ruby-buildpack
- dotnet-core-buildpack
- staticfile-buildpack
- nginx-buildpack

**Special Environments:**
- releases (cf-release pipeline) - Uses `releases-buildpack-state` directory and `cf-release/deploy` job

## Contributing

When modifying this tool:

1. Follow the existing modular, functional design
2. Keep functions pure and testable
3. Add comprehensive error handling
4. Update this README with any new configuration options
5. Test with multiple environments

## Related Resources

- GCP Project: https://console.cloud.google.com/home/dashboard?project=app-runtime-interfaces-wg
- Concourse: https://concourse.app-runtime-interfaces.ci.cloudfoundry.org
- buildpacks-envs repo: https://github.com/cloudfoundry/buildpacks-envs
