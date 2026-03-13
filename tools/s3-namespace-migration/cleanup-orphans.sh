#!/usr/bin/env bash
# cleanup-orphans.sh
#
# Manually deletes blobs that were previously moved to the "orphaned/" folder
# by migrate-orphans.sh.
#
# Run this script when you are confident the orphaned blobs are no longer
# needed and want to reclaim storage.
#
# Safety guarantees:
#   - Only deletes blobs that actually exist under orphaned/ in S3.
#   - Will not touch any blob outside the orphaned/ prefix.
#   - Requires interactive confirmation before deleting (unless --dry-run).
#
# Prerequisites:
#   - AWS CLI configured with access to the target bucket
#   - uuid-mapper output CSVs in the input directory:
#       orphaned_blobs.csv  (uuid,size,last_modified,status)
#
# Usage:
#   ./cleanup-orphans.sh [OPTIONS]
#
# Options:
#   --bucket BUCKET       S3 bucket name (default: buildpacks.cloudfoundry.org)
#   --input-dir DIR       Directory containing uuid-mapper CSV output
#                         (default: ../uuid-mapper/output)
#   --dry-run             Print delete commands without executing them
#   --help                Show this help message
#
# Exit codes:
#   0 - All eligible blobs deleted (or dry-run completed)
#   1 - One or more deletions failed

set -euo pipefail
shopt -s inherit_errexit

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BUCKET="buildpacks.cloudfoundry.org"
DEFAULT_INPUT_DIR="${SCRIPT_DIR}/../uuid-mapper/output"
ORPHANED_FOLDER="orphaned"

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

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bucket)    BUCKET="$2";    shift 2 ;;
      --input-dir) INPUT_DIR="$2"; shift 2 ;;
      --dry-run)   DRY_RUN=true;   shift   ;;
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
    log_error "AWS CLI not found. Install it and configure credentials."
    exit 1
  fi

  if [[ ! -f "${INPUT_DIR}/orphaned_blobs.csv" ]]; then
    log_error "Missing: ${INPUT_DIR}/orphaned_blobs.csv"
    log_error "Run the uuid-mapper tool first:"
    log_error "  cd tools/uuid-mapper && ./mapper.py --no-serve"
    exit 1
  fi
}

validate_s3_access() {
  log_info "Verifying S3 access to s3://${BUCKET}/..."
  if ! aws s3api list-objects-v2 --bucket "${BUCKET}" --max-items 1 &>/dev/null; then
    log_error "Cannot access s3://${BUCKET}/. Check AWS credentials and bucket name."
    exit 1
  fi
  log_success "S3 access confirmed."
}

# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

confirm_deletion() {
  local count="$1"
  local total_size_gb="$2"

  echo ""
  log_warning "About to DELETE ${count} orphaned blob(s) (${total_size_gb} GB) from:"
  log_warning "  s3://${BUCKET}/${ORPHANED_FOLDER}/"
  echo ""
  echo "  These blobs were previously moved to orphaned/ by migrate-orphans.sh."
  echo "  They are NOT referenced by any buildpack release repo."
  echo "  This operation is IRREVERSIBLE."
  echo ""
  read -r -p "  Type 'yes' to proceed: " confirmation
  if [[ "${confirmation}" != "yes" ]]; then
    log_info "Aborted by user."
    exit 0
  fi
}

orphaned_blob_exists() {
  local bucket="$1"
  local uuid="$2"

  aws s3api head-object \
    --bucket "${bucket}" \
    --key "${ORPHANED_FOLDER}/${uuid}" \
    &>/dev/null
}

delete_orphaned_blob() {
  local bucket="$1"
  local uuid="$2"

  local target="s3://${bucket}/${ORPHANED_FOLDER}/${uuid}"

  if "${DRY_RUN}"; then
    echo "[DRY-RUN] aws s3 rm ${target}"
    return 0
  fi

  # Skip if already gone
  if ! orphaned_blob_exists "${bucket}" "${uuid}"; then
    echo "[SKIP]    ${ORPHANED_FOLDER}/${uuid} — not found (already deleted?)"
    return 0
  fi

  if aws s3 rm "${target}" --only-show-errors; then
    echo "[DELETED] ${ORPHANED_FOLDER}/${uuid}"
  else
    echo "[FAILED]  ${ORPHANED_FOLDER}/${uuid}" >&2
    return 1
  fi
}

run_cleanup() {
  local input_file="${INPUT_DIR}/orphaned_blobs.csv"

  # Count entries and compute total size (skip header)
  local count=0
  local total_bytes=0

  while IFS=, read -r uuid size _rest; do
    [[ "${uuid}" == "uuid" ]] && continue
    count=$((count + 1))
    total_bytes=$((total_bytes + size))
  done < "${input_file}"

  local total_size_gb
  total_size_gb="$(awk "BEGIN { printf \"%.2f\", ${total_bytes}/1073741824 }")"

  log_info "Orphaned blobs found in CSV: ${count} (${total_size_gb} GB)"

  if [[ "${count}" -eq 0 ]]; then
    log_success "No orphaned blobs to delete."
    return 0
  fi

  if "${DRY_RUN}"; then
    log_warning "DRY-RUN mode: no changes will be made to S3."
  else
    confirm_deletion "${count}" "${total_size_gb}"
  fi

  local deleted=0
  local skipped=0
  local failed=0

  while IFS=, read -r uuid _rest; do
    [[ "${uuid}" == "uuid" ]] && continue

    result=$(delete_orphaned_blob "${BUCKET}" "${uuid}" 2>&1)
    local rc=$?
    echo "${result}"

    case "${rc}" in
      0)
        if   [[ "${result}" == *"[DELETED]"* ]];  then deleted=$((deleted + 1))
        elif [[ "${result}" == *"[SKIP]"* ]];     then skipped=$((skipped + 1))
        elif [[ "${result}" == *"[DRY-RUN]"* ]];  then deleted=$((deleted + 1))
        fi
        ;;
      *) failed=$((failed + 1)) ;;
    esac
  done < "${input_file}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Orphan Cleanup Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  Deleted: %d\n" "${deleted}"
  printf "  Skipped: %d (not found in orphaned/ — already deleted?)\n" "${skipped}"
  printf "  Failed:  %d\n" "${failed}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "${failed}" -gt 0 ]]; then
    log_error "${failed} blob(s) failed to delete. Check output above."
    exit 1
  fi

  log_success "Orphan cleanup complete."
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  S3 Orphan Cleanup - Buildpacks CI"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  parse_args "$@"
  validate_prerequisites
  validate_s3_access

  log_info "Bucket:    s3://${BUCKET}/"
  log_info "Input dir: ${INPUT_DIR}"

  run_cleanup
}

main "$@"
