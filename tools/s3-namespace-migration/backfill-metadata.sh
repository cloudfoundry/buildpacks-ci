#!/usr/bin/env bash
# backfill-metadata.sh
#
# For blobs already copied to namespaced folders (before metadata preservation
# was added to migrate-blobs.sh), this script backfills the
# original-last-modified metadata by re-copying each object onto itself.
#
# S3 supports in-place copy (source == destination) to update metadata.
# The ETag and content are unchanged; only the metadata is added.
#
# Prerequisites:
#   - AWS CLI configured with access to the target bucket
#   - uuid-mapper output CSVs in the input directory
#
# Usage:
#   ./backfill-metadata.sh [OPTIONS]
#
# Options:
#   --bucket BUCKET       S3 bucket name (default: buildpacks.cloudfoundry.org)
#   --input-dir DIR       Directory containing uuid-mapper CSV output
#                         (default: ../uuid-mapper/output)
#   --dry-run             Print commands without executing them
#   --buildpack NAME      Backfill only the specified buildpack namespace
#   --help                Show this help message

set -euo pipefail
shopt -s inherit_errexit

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BUCKET="buildpacks.cloudfoundry.org"
DEFAULT_INPUT_DIR="${SCRIPT_DIR}/../uuid-mapper/output"

declare -A REPO_TO_FOLDER=(
  ["binary-buildpack-release"]="binary-buildpack"
  ["dotnet-core-buildpack-release"]="dotnet-core-buildpack"
  ["go-buildpack-release"]="go-buildpack"
  ["hwc-buildpack-release"]="hwc-buildpack"
  ["java-buildpack-release"]="java-buildpack"
  ["java-offline-buildpack-release"]="java-offline-buildpack"
  ["nginx-buildpack-release"]="nginx-buildpack"
  ["nodejs-buildpack-release"]="nodejs-buildpack"
  ["php-buildpack-release"]="php-buildpack"
  ["python-buildpack-release"]="python-buildpack"
  ["r-buildpack-release"]="r-buildpack"
  ["ruby-buildpack-release"]="ruby-buildpack"
  ["staticfile-buildpack-release"]="staticfile-buildpack"
  ["cflinuxfs3-release"]="cflinuxfs3"
  ["cflinuxfs4-release"]="cflinuxfs4"
)

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

log_info()    { echo "[INFO]    $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_warning() { echo "[WARNING] $*"; }
log_error()   { echo "[ERROR]   $*" >&2; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

parse_args() {
  BUCKET="${DEFAULT_BUCKET}"
  INPUT_DIR="${DEFAULT_INPUT_DIR}"
  DRY_RUN=false
  FILTER_BUILDPACK=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bucket)    BUCKET="$2";           shift 2 ;;
      --input-dir) INPUT_DIR="$2";        shift 2 ;;
      --dry-run)   DRY_RUN=true;          shift   ;;
      --buildpack) FILTER_BUILDPACK="$2"; shift 2 ;;
      --help)      usage; exit 0 ;;
      *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done
}

usage() {
  sed -n '/^# Usage:/,/^[^#]/{ /^#/{ s/^# \{0,1\}//; p } }' "${BASH_SOURCE[0]}"
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

validate_prerequisites() {
  if ! command -v aws &>/dev/null; then
    log_error "AWS CLI not found."
    exit 1
  fi

  if [[ ! -f "${INPUT_DIR}/all_blob_history.csv" ]]; then
    log_error "Missing: ${INPUT_DIR}/all_blob_history.csv"
    log_error "Run the uuid-mapper tool first."
    exit 1
  fi
}

validate_s3_access() {
  log_info "Verifying S3 access to s3://${BUCKET}/..."
  if ! aws s3api list-objects-v2 --bucket "${BUCKET}" --max-items 1 &>/dev/null; then
    log_error "Cannot access s3://${BUCKET}/."
    exit 1
  fi
  log_success "S3 access confirmed."
}

# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

# Build uuid → folder map from all_blob_history.csv (same as migrate-blobs.sh)
build_uuid_to_folder_map() {
  local input_file="${INPUT_DIR}/all_blob_history.csv"
  local map_file="${INPUT_DIR}/.uuid_to_folder_map.tmp"

  log_info "Building UUID → folder mapping from ${input_file}..." >&2

  : > "${map_file}"

  local mapped=0
  local skipped=0

  while IFS=, read -r uuid _filename _size _sha repo _rest; do
    [[ "${uuid}" == "uuid" ]] && continue

    local folder="${REPO_TO_FOLDER[${repo}]:-}"
    if [[ -z "${folder}" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    if [[ -n "${FILTER_BUILDPACK}" && "${folder}" != "${FILTER_BUILDPACK}" ]]; then
      continue
    fi

    echo "${uuid} ${folder}" >> "${map_file}"
    mapped=$((mapped + 1))
  done < "${input_file}"

  sort -u "${map_file}" -o "${map_file}"

  log_info "Entries skipped (unknown repo): ${skipped}" >&2
  log_success "Unique UUID → folder mappings: $(wc -l < "${map_file}")" >&2

  echo "${map_file}"
}

# Backfill original-last-modified metadata on a single already-copied blob.
# Reads the root object's LastModified and re-copies the namespaced object
# onto itself with that value stored as custom metadata.
backfill_blob() {
  local bucket="$1"
  local folder="$2"
  local uuid="$3"
  local key="${folder}/${uuid}"

  # Skip if namespaced blob does not exist (not yet migrated)
  if ! aws s3api head-object --bucket "${bucket}" --key "${key}" &>/dev/null; then
    echo "[SKIP]    ${key} (not yet migrated)"
    return 0
  fi

  # Skip if metadata already set
  local existing_meta
  existing_meta="$(aws s3api head-object \
    --bucket "${bucket}" \
    --key "${key}" \
    --query 'Metadata."original-last-modified"' \
    --output text)"

  if [[ "${existing_meta}" != "None" && -n "${existing_meta}" ]]; then
    echo "[SKIP]    ${key} (already has original-last-modified=${existing_meta})"
    return 0
  fi

  # Fetch original LastModified from the root blob
  local original_date
  original_date="$(aws s3api head-object \
    --bucket "${bucket}" \
    --key "${uuid}" \
    --query 'LastModified' \
    --output text)"

  if "${DRY_RUN}"; then
    echo "[DRY-RUN] set metadata original-last-modified=${original_date} on ${key}"
    return 0
  fi

  # In-place copy to update metadata (REPLACE directive overwrites all metadata)
  if aws s3api copy-object \
    --bucket "${bucket}" \
    --copy-source "${bucket}/${key}" \
    --key "${key}" \
    --metadata "original-last-modified=${original_date}" \
    --metadata-directive REPLACE \
    --server-side-encryption AES256 \
    &>/dev/null; then
    echo "[BACKFILLED] ${key}  original-last-modified=${original_date}"
  else
    echo "[FAILED]     ${key}" >&2
    return 1
  fi
}

run_backfill() {
  local map_file="$1"
  local total
  total="$(wc -l < "${map_file}")"

  log_info "Backfilling metadata for up to ${total} blobs in s3://${BUCKET}/..."
  "${DRY_RUN}" && log_warning "DRY-RUN mode: no changes will be made to S3."

  local backfilled=0
  local skipped=0
  local failed=0

  while IFS=' ' read -r uuid folder; do
    result="$(backfill_blob "${BUCKET}" "${folder}" "${uuid}" 2>&1)"
    echo "${result}"

    case "${result}" in
      "[BACKFILLED]"*) backfilled=$((backfilled + 1)) ;;
      "[SKIP]"*)       skipped=$((skipped + 1)) ;;
      "[DRY-RUN]"*)    backfilled=$((backfilled + 1)) ;;
      *)               failed=$((failed + 1)) ;;
    esac
  done < "${map_file}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Backfill Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  Backfilled: %d\n" "${backfilled}"
  printf "  Skipped:    %d (already set or not yet migrated)\n" "${skipped}"
  printf "  Failed:     %d\n" "${failed}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "${failed}" -gt 0 ]]; then
    log_error "${failed} blobs failed. Check output above for details."
    return 1
  fi

  log_success "Backfill complete."
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  S3 Metadata Backfill - Buildpacks CI"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  parse_args "$@"
  validate_prerequisites
  validate_s3_access

  log_info "Bucket:    s3://${BUCKET}/"
  log_info "Input dir: ${INPUT_DIR}"
  [[ -n "${FILTER_BUILDPACK}" ]] && log_info "Filter:    ${FILTER_BUILDPACK}"

  local map_file
  map_file="$(build_uuid_to_folder_map)"

  run_backfill "${map_file}"
}

main "$@"
