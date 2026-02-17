#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# GCP Buildpack Environment Checkup Tool
# Detects orphaned GCP buildpack environments not part of running Concourse jobs

# ANSI Color Codes
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_RESET='\033[0m'

# Configuration with defaults
readonly GCP_PROJECT="${GCP_PROJECT:-app-runtime-interfaces-wg}"
readonly CONCOURSE_URL="${CONCOURSE_URL:-https://concourse.app-runtime-interfaces.ci.cloudfoundry.org}"
readonly CONCOURSE_TEAM="${CONCOURSE_TEAM:-buildpacks-team}"
readonly CONCOURSE_TARGET="${CONCOURSE_TARGET:-buildpacks}"
readonly GITHUB_REPO="${GITHUB_REPO:-cloudfoundry/buildpacks-envs}"
readonly OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
readonly DEBUG="${DEBUG:-false}"
readonly NO_COLOR="${NO_COLOR:-false}"
readonly GCP_SERVICE_ACCOUNT_KEY="${GCP_SERVICE_ACCOUNT_KEY:-}"

# Script directory for cache
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CACHE_DIR="${SCRIPT_DIR}/.cache"
readonly BUILDPACKS_ENVS_DIR="${CACHE_DIR}/buildpacks-envs"

# Enable debug mode if requested
if [[ "${DEBUG}" == "true" ]]; then
    set -o xtrace
fi

# Color helper functions
function color_red() {
    if [[ "${NO_COLOR}" == "true" ]] || [[ "${OUTPUT_FORMAT}" == "json" ]]; then
        echo "$1"
    else
        echo -e "${COLOR_RED}${1}${COLOR_RESET}"
    fi
}

function color_green() {
    if [[ "${NO_COLOR}" == "true" ]] || [[ "${OUTPUT_FORMAT}" == "json" ]]; then
        echo "$1"
    else
        echo -e "${COLOR_GREEN}${1}${COLOR_RESET}"
    fi
}

function color_yellow() {
    if [[ "${NO_COLOR}" == "true" ]] || [[ "${OUTPUT_FORMAT}" == "json" ]]; then
        echo "$1"
    else
        echo -e "${COLOR_YELLOW}${1}${COLOR_RESET}"
    fi
}

function color_blue() {
    if [[ "${NO_COLOR}" == "true" ]] || [[ "${OUTPUT_FORMAT}" == "json" ]]; then
        echo "$1"
    else
        echo -e "${COLOR_BLUE}${1}${COLOR_RESET}"
    fi
}

function color_cyan() {
    if [[ "${NO_COLOR}" == "true" ]] || [[ "${OUTPUT_FORMAT}" == "json" ]]; then
        echo "$1"
    else
        echo -e "${COLOR_CYAN}${1}${COLOR_RESET}"
    fi
}

function color_bold() {
    if [[ "${NO_COLOR}" == "true" ]] || [[ "${OUTPUT_FORMAT}" == "json" ]]; then
        echo "$1"
    else
        echo -e "${COLOR_BOLD}${1}${COLOR_RESET}"
    fi
}

# Dependency Checker - validates required CLI tools
# Input: mode (optional) - "cleanup" requires additional tools
# Returns: 0 if all dependencies present, 1 otherwise
function check_dependencies() {
    local mode="${1:-check}"
    local missing_deps=()
    local required_tools=("gcloud" "fly" "jq" "git")
    
    # Additional tools required for cleanup mode
    if [[ "${mode}" == "cleanup" ]]; then
        required_tools+=("bbl" "bosh" "leftovers")
    fi
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            missing_deps+=("${tool}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "ERROR: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install: ${missing_deps[*]}" >&2
        return 1
    fi
    
    return 0
}

# Check CLI authentication status
# Returns: 0 if all CLIs are authenticated, 1 otherwise
function check_authentication() {
    local auth_failed=false
    
    # Check gcloud authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        echo "ERROR: gcloud not authenticated. Run: gcloud auth login" >&2
        auth_failed=true
    fi
    
    # Check fly authentication
    if ! fly -t "${CONCOURSE_TARGET}" status &> /dev/null; then
        echo "ERROR: fly not authenticated for target '${CONCOURSE_TARGET}'. Run: fly -t ${CONCOURSE_TARGET} login -c ${CONCOURSE_URL} -n ${CONCOURSE_TEAM}" >&2
        auth_failed=true
    fi
    
    if [[ "${auth_failed}" == "true" ]]; then
        return 1
    fi
    
    return 0
}

# Extract buildpack identifier from VPC network name
# Input: VPC network name (e.g., "binary-buildpack-bbl-env-network" or "releases-buildpack-bbl-env-network")
# Output: identifier (e.g., "binary" or "releases")
function extract_identifier_from_network() {
    local network_name="$1"
    echo "${network_name}" | sed 's/-buildpack-bbl-env-network$//'
}

# List GCP VPC networks matching buildpack pattern
# Returns: JSON array of network names
function list_buildpack_networks() {
    local networks
    
    networks=$(gcloud compute networks list \
        --project="${GCP_PROJECT}" \
        --filter="name~'-buildpack-bbl-env-network$'" \
        --format="json" 2>/dev/null)
    
    if [[ -z "${networks}" ]] || [[ "${networks}" == "[]" ]]; then
        echo "[]"
        return 0
    fi
    
    echo "${networks}" | jq -r '[.[].name]'
}

# Check if Concourse job is currently running
# Input: identifier (e.g., "binary" or "releases")
# Returns: 0 if job is running, 1 if not running
function is_concourse_job_running() {
    local identifier="$1"
    local pipeline
    local job
    
    # Special case for cf-release pipeline
    if [[ "${identifier}" == "releases" ]]; then
        pipeline="cf-release"
        job="deploy"
    else
        # Standard buildpack pipeline
        pipeline="${identifier}-buildpack"
        job="create-cf-infrastructure-and-execute-integration-test-for-${identifier}-cflinuxfs4"
    fi
    
    # Get latest build for the job
    local build_status
    build_status=$(fly -t "${CONCOURSE_TARGET}" builds \
        -j "${pipeline}/${job}" \
        -c 1 2>/dev/null | tail -n 1 | awk '{print $4}')
    
    if [[ "${build_status}" == "started" ]]; then
        return 0
    fi
    
    return 1
}

# Check if buildpacks-envs state directory is empty
# Input: identifier (e.g., "binary" or "releases")
# Returns: 0 if empty/non-existent, 1 if has meaningful content
function is_state_directory_empty() {
    local identifier="$1"
    local state_dir="${BUILDPACKS_ENVS_DIR}/${identifier}-buildpack-state"
    
    # If directory doesn't exist, consider it empty
    if [[ ! -d "${state_dir}" ]]; then
        return 0
    fi
    
    # Count files and directories (excluding . and ..)
    local item_count
    item_count=$(find "${state_dir}" -mindepth 1 -maxdepth 1 | wc -l)
    
    # Directory is truly empty
    if [[ "${item_count}" -eq 0 ]]; then
        return 0
    fi
    
    # Check if only terraform directory exists (considered empty if it only has lock file)
    local non_terraform_items
    non_terraform_items=$(find "${state_dir}" -mindepth 1 -maxdepth 1 ! -name "terraform" | wc -l)
    
    # If there are files/dirs other than terraform, it's not empty
    if [[ "${non_terraform_items}" -gt 0 ]]; then
        return 1
    fi
    
    # Only terraform dir exists, check its contents
    local terraform_dir="${state_dir}/terraform"
    if [[ ! -d "${terraform_dir}" ]]; then
        # terraform dir doesn't exist but state_dir has something - not empty
        return 1
    fi
    
    # Count files in terraform directory (excluding . and ..)
    local terraform_item_count
    terraform_item_count=$(find "${terraform_dir}" -mindepth 1 -maxdepth 1 | wc -l)
    
    if [[ "${terraform_item_count}" -eq 0 ]]; then
        # terraform dir exists but is empty - consider state empty
        return 0
    fi
    
    # Check if terraform dir only contains .terraform.lock.hcl
    local non_lock_files
    non_lock_files=$(find "${terraform_dir}" -mindepth 1 -maxdepth 1 ! -name ".terraform.lock.hcl" | wc -l)
    
    if [[ "${non_lock_files}" -eq 0 ]]; then
        # Only .terraform.lock.hcl exists - consider state empty
        return 0
    fi
    
    # Directory has meaningful content
    return 1
}

# List all buildpack state directories from local repository
# Returns: JSON array of identifiers with state directories
function list_buildpack_state_directories() {
    local identifiers="[]"
    
    # Check if buildpacks-envs directory exists
    if [[ ! -d "${BUILDPACKS_ENVS_DIR}" ]]; then
        echo "[]"
        return 0
    fi
    
    # Find all directories matching *-buildpack-state pattern
    while IFS= read -r dir; do
        if [[ -n "${dir}" ]]; then
            local identifier
            identifier=$(basename "${dir}" | sed 's/-buildpack-state$//')
            identifiers=$(echo "${identifiers}" | jq --arg id "${identifier}" '. + [$id]')
        fi
    done < <(find "${BUILDPACKS_ENVS_DIR}" -mindepth 1 -maxdepth 1 -type d -name "*-buildpack-state")
    
    echo "${identifiers}"
}

# Analyze a single buildpack environment
# Input: network name
# Output: JSON object with analysis results
function analyze_environment() {
    local network_name="$1"
    local identifier
    identifier=$(extract_identifier_from_network "${network_name}")
    
    local job_running="false"
    local state_empty="unknown"
    local is_orphaned="false"
    local pipeline
    local job
    
    # Determine pipeline and job based on identifier
    if [[ "${identifier}" == "releases" ]]; then
        pipeline="cf-release"
        job="deploy"
    else
        pipeline="${identifier}-buildpack"
        job="create-cf-infrastructure-and-execute-integration-test-for-${identifier}-cflinuxfs4"
    fi
    
    # Check Concourse job status
    if is_concourse_job_running "${identifier}"; then
        job_running="true"
    fi
    
    # Check buildpacks-envs state
    if is_state_directory_empty "${identifier}"; then
        state_empty="true"
    else
        state_empty="false"
    fi
    
    # Determine if orphaned: VPC exists and job not running
    # State directory status is informational but not required for orphan detection
    if [[ "${job_running}" == "false" ]]; then
        is_orphaned="true"
    fi
    
    # Build JSON result
    jq -n \
        --arg network "${network_name}" \
        --arg identifier "${identifier}" \
        --arg pipeline "${pipeline}" \
        --arg job "${job}" \
        --arg job_running "${job_running}" \
        --arg state_empty "${state_empty}" \
        --arg orphaned "${is_orphaned}" \
        --arg type "vpc" \
        '{
            type: $type,
            network: $network,
            identifier: $identifier,
            pipeline: $pipeline,
            job: $job,
            concourse_job_running: ($job_running == "true"),
            state_directory_empty: ($state_empty == "true"),
            is_orphaned: ($orphaned == "true")
        }'
}

# Analyze orphaned state directory (state exists but no VPC and no job)
# Input: identifier
# Output: JSON object with analysis results
function analyze_orphaned_state() {
    local identifier="$1"
    local job_running="false"
    local pipeline
    local job
    
    # Determine pipeline and job based on identifier
    if [[ "${identifier}" == "releases" ]]; then
        pipeline="cf-release"
        job="deploy"
    else
        pipeline="${identifier}-buildpack"
        job="create-cf-infrastructure-and-execute-integration-test-for-${identifier}-cflinuxfs4"
    fi
    
    # Check Concourse job status
    if is_concourse_job_running "${identifier}"; then
        job_running="true"
    fi
    
    # Build JSON result for orphaned state
    jq -n \
        --arg identifier "${identifier}" \
        --arg pipeline "${pipeline}" \
        --arg job "${job}" \
        --arg job_running "${job_running}" \
        --arg type "state-only" \
        '{
            type: $type,
            network: null,
            identifier: $identifier,
            pipeline: $pipeline,
            job: $job,
            concourse_job_running: ($job_running == "true"),
            state_directory_empty: false,
            is_orphaned: true
        }'
}

# Generate text report from analysis results
# Input: JSON array of analysis results
function generate_text_report() {
    local results="$1"
    local orphaned_count
    orphaned_count=$(echo "${results}" | jq '[.[] | select(.is_orphaned == true)] | length')
    
    color_bold "======================================"
    color_bold "GCP Buildpack Environment Checkup"
    color_bold "======================================"
    echo ""
    color_cyan "GCP Project: ${GCP_PROJECT}"
    color_cyan "Concourse: ${CONCOURSE_URL}"
    color_cyan "GitHub Repo: ${GITHUB_REPO}"
    echo ""
    
    if [[ "${orphaned_count}" -eq 0 ]]; then
        color_green "✓ No orphaned environments found"
        echo ""
    else
        color_yellow "⚠ Found ${orphaned_count} orphaned environment(s)"
        echo ""
    fi
    
    color_bold "All Environments:"
    color_blue "-------------------------------------"
    
    # Process all environments
    while IFS= read -r env; do
        local identifier pipeline job network is_orphaned job_running state_empty env_type
        identifier=$(echo "$env" | jq -r '.identifier')
        pipeline=$(echo "$env" | jq -r '.pipeline')
        job=$(echo "$env" | jq -r '.job')
        network=$(echo "$env" | jq -r '.network')
        is_orphaned=$(echo "$env" | jq -r '.is_orphaned')
        job_running=$(echo "$env" | jq -r '.concourse_job_running')
        state_empty=$(echo "$env" | jq -r '.state_directory_empty')
        env_type=$(echo "$env" | jq -r '.type')
        
        # Header with color based on orphan status
        if [[ "$is_orphaned" == "true" ]]; then
            color_red "  • ${identifier} (${pipeline}/${job})"
        else
            color_green "  • ${identifier} (${pipeline}/${job})"
        fi
        
        # Network (always plain, null for state-only)
        if [[ "$network" == "null" ]]; then
            color_yellow "    Network: None (state-only orphan)"
        else
            echo "    Network: ${network}"
        fi
        
        # Job Running status with color
        if [[ "$job_running" == "true" ]]; then
            color_green "    Job Running: Yes"
        else
            color_yellow "    Job Running: No"
        fi
        
        # State Empty (plain)
        if [[ "$state_empty" == "true" ]]; then
            echo "    State Empty: Yes"
        else
            echo "    State Empty: No"
        fi
        
        # Orphaned status with color
        if [[ "$is_orphaned" == "true" ]]; then
            if [[ "$env_type" == "state-only" ]]; then
                color_red "    Orphaned: YES (state-only) ⚠"
            else
                color_red "    Orphaned: YES ⚠"
            fi
        else
            echo "    Orphaned: No"
        fi
        
        echo ""
    done < <(echo "${results}" | jq -c '.[]')
}

# Clone or update buildpacks-envs repository
# Returns: 0 on success, 1 on failure
function setup_buildpacks_envs_repo() {
    if [[ -d "${BUILDPACKS_ENVS_DIR}" ]]; then
        echo "Updating buildpacks-envs repository..." >&2
        cd "${BUILDPACKS_ENVS_DIR}"
        if ! git pull --quiet origin master; then
            echo "ERROR: Failed to pull buildpacks-envs repository" >&2
            return 1
        fi
    else
        echo "Cloning buildpacks-envs repository..." >&2
        mkdir -p "${CACHE_DIR}"
        if ! git clone --quiet "https://github.com/${GITHUB_REPO}.git" "${BUILDPACKS_ENVS_DIR}"; then
            echo "ERROR: Failed to clone buildpacks-envs repository" >&2
            return 1
        fi
    fi
    return 0
}

# Interactive menu for selecting environments to cleanup
# Input: JSON array of orphaned environments
# Output: JSON array of selected environments
function select_environments_for_cleanup() {
    local orphaned_envs="$1"
    local orphaned_count
    orphaned_count=$(echo "${orphaned_envs}" | jq 'length')
    
    if [[ "${orphaned_count}" -eq 0 ]]; then
        echo "No orphaned environments to cleanup" >&2
        echo "[]"
        return 0
    fi
    
    echo "" >&2
    color_bold "======================================" >&2
    color_bold "Select Environments for Cleanup" >&2
    color_bold "======================================" >&2
    echo "" >&2
    
    # Display orphaned environments with numbers
    local idx=1
    while IFS= read -r env; do
        local identifier network env_type
        identifier=$(echo "$env" | jq -r '.identifier')
        network=$(echo "$env" | jq -r '.network')
        env_type=$(echo "$env" | jq -r '.type')
        
        if [[ "${network}" == "null" ]]; then
            color_yellow "  ${idx}. ${identifier} (state-only)" >&2
        else
            color_yellow "  ${idx}. ${identifier} (${network})" >&2
        fi
        idx=$((idx + 1))
    done < <(echo "${orphaned_envs}" | jq -c '.[]')
    
    echo "" >&2
    color_cyan "  a. All orphaned environments" >&2
    color_cyan "  c. Cancel" >&2
    echo "" >&2
    
    # Read user selection
    read -rp "Select environments (comma-separated numbers, 'a' for all, or 'c' to cancel): " selection
    
    # Handle cancel
    if [[ "${selection}" == "c" ]] || [[ "${selection}" == "C" ]]; then
        echo "Cleanup cancelled" >&2
        echo "[]"
        return 0
    fi
    
    # Handle all
    if [[ "${selection}" == "a" ]] || [[ "${selection}" == "A" ]]; then
        echo "${orphaned_envs}"
        return 0
    fi
    
    # Parse comma-separated selections
    local selected_envs="[]"
    IFS=',' read -ra selections <<< "${selection}"
    
    for sel in "${selections[@]}"; do
        # Trim whitespace
        sel=$(echo "${sel}" | xargs)
        
        # Validate it's a number
        if ! [[ "${sel}" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid selection '${sel}'. Must be a number." >&2
            echo "[]"
            return 1
        fi
        
        # Convert to 0-indexed array position
        local array_idx=$((sel - 1))
        
        # Get environment at this index
        local env
        env=$(echo "${orphaned_envs}" | jq --argjson idx "${array_idx}" '.[$idx]')
        
        if [[ "${env}" == "null" ]]; then
            echo "ERROR: Invalid selection '${sel}'. Out of range." >&2
            echo "[]"
            return 1
        fi
        
        selected_envs=$(echo "${selected_envs}" | jq --argjson new "${env}" '. + [$new]')
    done
    
    echo "${selected_envs}"
}

# Cleanup a single environment
# Input: environment JSON object
# Returns: 0 on success, 1 on failure
function cleanup_environment() {
    local env="$1"
    local identifier
    identifier=$(echo "$env" | jq -r '.identifier')
    
    local env_type
    env_type=$(echo "$env" | jq -r '.type')
    
    local state_dir="${BUILDPACKS_ENVS_DIR}/${identifier}-buildpack-state"
    
    color_bold "======================================" >&2
    color_bold "Cleaning up: ${identifier}" >&2
    color_bold "======================================" >&2
    echo "" >&2
    
    # Check if state directory exists
    if [[ ! -d "${state_dir}" ]]; then
        color_yellow "⚠ State directory not found: ${state_dir}" >&2
        color_yellow "  Cannot cleanup without state directory" >&2
        return 1
    fi
    
    # For state-only orphans, skip infrastructure cleanup entirely
    # (no VPC exists, so there's nothing to destroy with BBL/BOSH/leftovers)
    if [[ "${env_type}" == "state-only" ]]; then
        color_yellow "→ State-only orphan detected (no VPC found), skipping infrastructure cleanup..." >&2
    else
        # Change to state directory
        echo "→ Entering state directory..." >&2
        cd "${state_dir}" || {
            echo "ERROR: Failed to enter state directory: ${state_dir}" >&2
            return 1
        }
        
        # Load BBL environment
        echo "→ Loading BBL environment..." >&2
        if ! eval "$(bbl print-env)" 2>/dev/null; then
            color_yellow "⚠ Failed to load BBL environment (may be corrupted), skipping to state cleanup..." >&2
        else
            # Get BOSH deployments (best-effort, may fail if BOSH director is down)
            echo "→ Listing BOSH deployments..." >&2
            local deployments
            local bosh_available=true
            if ! deployments=$(bosh deployments --json 2>/dev/null | jq -r '.Tables[0].Rows[].name' 2>/dev/null); then
                color_yellow "⚠ Cannot connect to BOSH director (may already be destroyed)" >&2
                bosh_available=false
                deployments=""
            fi
            
            # Delete each deployment (only if BOSH is available)
            if [[ "${bosh_available}" == "true" ]] && [[ -n "${deployments}" ]]; then
                while IFS= read -r deployment; do
                    if [[ -n "${deployment}" ]]; then
                        echo "→ Deleting BOSH deployment: ${deployment}..." >&2
                        if ! bosh delete-deployment -d "${deployment}" -n; then
                            color_yellow "⚠ Failed to delete BOSH deployment: ${deployment}, continuing..." >&2
                        fi
                    fi
                done <<< "${deployments}"
            elif [[ "${bosh_available}" == "true" ]]; then
                echo "  No BOSH deployments to delete" >&2
            fi
            
            # Clean up BOSH (only if BOSH is available)
            if [[ "${bosh_available}" == "true" ]]; then
                echo "→ Running BOSH cleanup..." >&2
                if ! bosh clean-up --all -n 2>/dev/null; then
                    color_yellow "⚠ BOSH cleanup failed, continuing to BBL destroy..." >&2
                fi
            else
                echo "  Skipping BOSH cleanup (director unavailable)" >&2
            fi
            
            # Destroy BBL environment
            echo "→ Destroying BBL environment..." >&2
            if [[ -z "${GCP_SERVICE_ACCOUNT_KEY}" ]]; then
                echo "ERROR: GCP_SERVICE_ACCOUNT_KEY environment variable not set" >&2
                echo "       Please set it to the path of your GCP service account key file" >&2
                return 1
            fi
            
            if [[ ! -f "${GCP_SERVICE_ACCOUNT_KEY}" ]]; then
                echo "ERROR: GCP service account key file not found: ${GCP_SERVICE_ACCOUNT_KEY}" >&2
                return 1
            fi
            
            if ! bbl destroy --iaas gcp --gcp-service-account-key "${GCP_SERVICE_ACCOUNT_KEY}" -n; then
                color_yellow "⚠ BBL destroy failed, attempting nuclear cleanup with leftovers..." >&2
                
                # Nuclear option: use leftovers to clean up all resources
                local network
                network=$(echo "$env" | jq -r '.network')
                
                if [[ "${network}" != "null" ]] && [[ -n "${network}" ]]; then
                    echo "→ Running leftovers with filter: ${network}..." >&2
                    if ! leftovers --iaas gcp --gcp-service-account-key "${GCP_SERVICE_ACCOUNT_KEY}" --no-confirm --filter "${network}"; then
                        echo "ERROR: leftovers also failed. Manual cleanup may be required." >&2
                        return 1
                    fi
                    
                    color_yellow "✓ Nuclear cleanup with leftovers completed" >&2
                else
                    color_yellow "⚠ No network name available for leftovers, skipping..." >&2
                fi
            fi
        fi
    fi
    
    # Clean up state directory and commit changes
    echo "→ Cleaning up state directory..." >&2
    
    if [[ -d "${state_dir}" ]]; then
        # Remove all files in state directory (keeps the directory itself)
        rm -rf "${state_dir:?}/"*
        
        # Git operations
        cd "${BUILDPACKS_ENVS_DIR}" || {
            echo "ERROR: Failed to cd to buildpacks-envs directory" >&2
            return 1
        }
        
        # Stage changes
        git add "${identifier}-buildpack-state/" || {
            color_yellow "⚠ Failed to stage changes (continuing anyway)" >&2
        }
        
        # Check if there are changes to commit
        if git diff --cached --quiet; then
            color_yellow "⚠ No changes to commit (directory was already empty)" >&2
        else
            # Commit changes
            if git commit -m "cleanup ${identifier} environment"; then
                echo "→ Committed cleanup to buildpacks-envs repository" >&2
                
                # Push changes
                if git push origin master; then
                    echo "→ Pushed changes to remote repository" >&2
                else
                    color_yellow "⚠ Failed to push changes (you may need to push manually)" >&2
                fi
            else
                color_yellow "⚠ Commit failed unexpectedly" >&2
            fi
        fi
    else
        color_yellow "⚠ State directory not found, skipping git commit" >&2
    fi
    
    color_green "✓ Successfully cleaned up ${identifier}" >&2
    echo "" >&2
    
    return 0
}

# Interactive cleanup mode
# Input: JSON array of analysis results
function interactive_cleanup() {
    local results="$1"
    
    # Filter orphaned environments
    local orphaned_envs
    orphaned_envs=$(echo "${results}" | jq '[.[] | select(.is_orphaned == true)]')
    
    # Select environments for cleanup
    local selected_envs
    selected_envs=$(select_environments_for_cleanup "${orphaned_envs}")
    
    local selected_count
    selected_count=$(echo "${selected_envs}" | jq 'length')
    
    if [[ "${selected_count}" -eq 0 ]]; then
        echo "No environments selected for cleanup" >&2
        return 0
    fi
    
    # Show summary and confirm
    echo "" >&2
    color_bold "======================================" >&2
    color_bold "Cleanup Summary" >&2
    color_bold "======================================" >&2
    echo "" >&2
    color_yellow "The following environments will be cleaned up:" >&2
    echo "" >&2
    
    # Separate VPC and state-only orphans for clearer summary
    local has_vpc_orphans=false
    local has_state_only_orphans=false
    
    while IFS= read -r env; do
        local identifier network env_type
        identifier=$(echo "$env" | jq -r '.identifier')
        network=$(echo "$env" | jq -r '.network')
        env_type=$(echo "$env" | jq -r '.type')
        
        if [[ "${network}" == "null" ]]; then
            color_red "  • ${identifier} (state-only)" >&2
            has_state_only_orphans=true
        else
            color_red "  • ${identifier} (${network})" >&2
            has_vpc_orphans=true
        fi
    done < <(echo "${selected_envs}" | jq -c '.[]')
    
    echo "" >&2
    color_bold "This will:" >&2
    
    if [[ "${has_vpc_orphans}" == "true" ]]; then
        echo "  For VPC-based environments:" >&2
        echo "    1. Delete all BOSH deployments" >&2
        echo "    2. Run BOSH cleanup" >&2
        echo "    3. Destroy BBL environment (VPC, instances, etc.)" >&2
        echo "    4. Clean state directory and commit to buildpacks-envs" >&2
    fi
    
    if [[ "${has_state_only_orphans}" == "true" ]]; then
        if [[ "${has_vpc_orphans}" == "true" ]]; then
            echo "" >&2
        fi
        echo "  For state-only environments:" >&2
        echo "    1. Delete all files in state directory" >&2
        echo "    2. Commit changes to buildpacks-envs repository" >&2
        echo "    3. Push changes to remote" >&2
    fi
    
    echo "" >&2
    color_red "⚠ WARNING: This action is IRREVERSIBLE!" >&2
    echo "" >&2
    
    read -rp "Are you sure you want to proceed? (yes/no): " confirmation
    
    if [[ "${confirmation}" != "yes" ]]; then
        echo "Cleanup cancelled" >&2
        return 0
    fi
    
    # Execute cleanup for each selected environment
    local cleanup_failed=false
    while IFS= read -r env; do
        if ! cleanup_environment "${env}"; then
            cleanup_failed=true
            local identifier
            identifier=$(echo "$env" | jq -r '.identifier')
            color_red "✗ Failed to cleanup ${identifier}" >&2
            echo "Stopping cleanup process due to error" >&2
            break
        fi
    done < <(echo "${selected_envs}" | jq -c '.[]')
    
    if [[ "${cleanup_failed}" == "true" ]]; then
        return 1
    fi
    
    color_green "======================================" >&2
    color_green "All selected environments cleaned up successfully!" >&2
    color_green "======================================" >&2
    
    return 0
}

# Display usage information
function usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

GCP Buildpack Environment Checkup Tool
Detects and optionally cleans up orphaned GCP buildpack environments.

OPTIONS:
    -h, --help              Show this help message
    -c, --cleanup           Run in interactive cleanup mode
    --check-only            Run check only (default mode)

ENVIRONMENT VARIABLES:
    GCP_PROJECT             GCP project to check (default: app-runtime-interfaces-wg)
    CONCOURSE_URL           Concourse URL (default: https://concourse.app-runtime-interfaces.ci.cloudfoundry.org)
    CONCOURSE_TEAM          Concourse team (default: buildpacks-team)
    CONCOURSE_TARGET        Concourse target (default: buildpacks)
    GITHUB_REPO             GitHub repo for state (default: cloudfoundry/buildpacks-envs)
    GCP_SERVICE_ACCOUNT_KEY Path to GCP service account key (required for cleanup)
    OUTPUT_FORMAT           Output format: text or json (default: text)
    NO_COLOR                Disable colored output (default: false)
    DEBUG                   Enable debug mode (default: false)

EXAMPLES:
    # Check for orphaned environments
    ./check.sh

    # Interactive cleanup mode (requires bbl, bosh, git, leftovers)
    export GCP_SERVICE_ACCOUNT_KEY="/path/to/service-account-key.json"
    ./check.sh --cleanup

    # JSON output
    OUTPUT_FORMAT=json ./check.sh

DEPENDENCIES:
    Check mode requires: gcloud, fly, jq, git
    Cleanup mode requires additional tools: bbl, bosh, leftovers

REPOSITORY CLONING:
    The script clones the buildpacks-envs repository to a local cache at:
    scripts/gcp-env-checkup/.cache/buildpacks-envs/
    
    On subsequent runs, it will pull the latest changes from the repository.

CLEANUP MODE:
    Cleanup mode requires additional tools: bbl, bosh, git, leftovers
    
    If BBL destroy fails, the script automatically falls back to leftovers
    (nuclear option) to force-clean all GCP resources matching the environment.

EOF
}

# Main execution function
function main() {
    local mode="check"
    
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--cleanup)
                mode="cleanup"
                shift
                ;;
            --check-only)
                mode="check"
                shift
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    echo "Checking dependencies..." >&2
    check_dependencies "${mode}" || exit 1
    
    echo "Verifying authentication..." >&2
    check_authentication || exit 1
    
    # Setup buildpacks-envs repository (needed for both check and cleanup modes)
    echo "Setting up buildpacks-envs repository..." >&2
    if ! setup_buildpacks_envs_repo; then
        echo "ERROR: Failed to setup buildpacks-envs repository" >&2
        exit 1
    fi
    
    echo "Discovering buildpack VPC networks..." >&2
    local networks
    networks=$(list_buildpack_networks)
    
    local network_count
    network_count=$(echo "${networks}" | jq 'length')
    
    echo "Discovering buildpack state directories..." >&2
    local state_dirs
    state_dirs=$(list_buildpack_state_directories)
    
    local state_count
    state_count=$(echo "${state_dirs}" | jq 'length')
    
    if [[ "${network_count}" -eq 0 ]] && [[ "${state_count}" -eq 0 ]]; then
        echo "No buildpack networks or state directories found" >&2
        exit 0
    fi
    
    echo "Found ${network_count} buildpack network(s) and ${state_count} state director(ies). Analyzing..." >&2
    echo "" >&2
    
    # Analyze each network
    local results="[]"
    while IFS= read -r network_name; do
        echo "Checking ${network_name}..." >&2
        local analysis
        analysis=$(analyze_environment "${network_name}")
        results=$(echo "${results}" | jq --argjson new "${analysis}" '. + [$new]')
    done < <(echo "${networks}" | jq -r '.[]')
    
    # Find orphaned state directories (state exists but no VPC)
    # Build a list of identifiers that have VPC networks
    local vpc_identifiers
    vpc_identifiers=$(echo "${results}" | jq -r '[.[].identifier] | unique')
    
    # Check each state directory to see if it has a VPC
    while IFS= read -r identifier; do
        # Check if this identifier has a VPC
        local has_vpc
        has_vpc=$(echo "${vpc_identifiers}" | jq --arg id "${identifier}" 'any(. == $id)')
        
        if [[ "${has_vpc}" == "false" ]]; then
            # Check if state directory is empty (only terraform/.terraform.lock.hcl)
            # We only want to report non-empty orphaned states
            if ! is_state_directory_empty "${identifier}"; then
                # This is a non-empty orphaned state directory
                echo "Checking orphaned state: ${identifier}-buildpack-state..." >&2
                local analysis
                analysis=$(analyze_orphaned_state "${identifier}")
                results=$(echo "${results}" | jq --argjson new "${analysis}" '. + [$new]')
            fi
        fi
    done < <(echo "${state_dirs}" | jq -r '.[]')
    
    echo "" >&2
    
    # Output results based on format (only in check mode or before cleanup)
    if [[ "${OUTPUT_FORMAT}" == "json" ]]; then
        echo "${results}" | jq '.'
    else
        generate_text_report "${results}"
    fi
    
    # Run cleanup if requested
    if [[ "${mode}" == "cleanup" ]]; then
        local orphaned_count
        orphaned_count=$(echo "${results}" | jq '[.[] | select(.is_orphaned == true)] | length')
        
        if [[ "${orphaned_count}" -eq 0 ]]; then
            echo "No orphaned environments to cleanup" >&2
            exit 0
        fi
        
        interactive_cleanup "${results}" || exit 1
        exit 0
    fi
    
    # Exit with error code if orphaned environments found (check mode only)
    local orphaned_count
    orphaned_count=$(echo "${results}" | jq '[.[] | select(.is_orphaned == true)] | length')
    
    if [[ "${orphaned_count}" -gt 0 ]]; then
        exit 1
    fi
    
    exit 0
}

main "$@"
