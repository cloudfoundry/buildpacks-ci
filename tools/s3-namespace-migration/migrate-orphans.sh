#!/usr/bin/env bash
# migrate-orphans.sh
#
# Moves orphaned BOSH blobs from the S3 bucket root into an "orphaned/"
# folder. Orphaned blobs can then be deleted manually via cleanup-orphans.sh
# when you are confident they are no longer needed.
#
# An orphaned blob is one that exists in S3 but is not referenced in any
# current config/blobs.yml or .final_builds/ index across all buildpack
# release repositories. See orphaned_blobs.csv from the uuid-mapper tool.
#
# Prerequisites:
#   - AWS CLI configured with access to the target bucket
#   - uuid-mapper output CSVs in the input directory:
#       orphaned_blobs.csv  (uuid,size,last_modified,status)
#
# Usage:
#   ./migrate-orphans.sh [OPTIONS]
#
# Options:
#   --bucket BUCKET       S3 bucket name (default: buildpacks.cloudfoundry.org)
#   --input-dir DIR       Directory containing uuid-mapper CSV output
#                         (default: ../uuid-mapper/output)
#   --dry-run             Print move commands without executing them
#   --help                Show this help message

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
      --bucket)    BUCKET="$2";   shift 2 ;;
      --input-dir) INPUT_DIR="$2"; shift 2 ;;
      --dry-run)   DRY_RUN=true;  shift ;;
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

# Confirm the user wants to proceed — this is a destructive move operation
confirm_move() {
  local count="$1"
  local total_size_gb="$2"

  echo ""
  log_warning "About to MOVE ${count} orphaned blobs (${total_size_gb} GB total) to:"
  log_warning "  s3://${BUCKET}/${ORPHANED_FOLDER}/"
  echo ""
  echo "  These blobs are NOT referenced in any current blobs.yml or .final_builds/."
  echo "  They will be moved to '${ORPHANED_FOLDER}/' and can be deleted via cleanup-orphans.sh."
  echo "  Run cleanup-orphans.sh when you are confident they are no longer needed."
  echo ""
  read -r -p "  Type 'yes' to proceed: " confirmation
  if [[ "${confirmation}" != "yes" ]]; then
    log_info "Aborted by user."
    exit 0
  fi
}

blob_exists_at_source() {
  local bucket="$1"
  local uuid="$2"

  aws s3api head-object \
    --bucket "${bucket}" \
    --key "${uuid}" \
    &>/dev/null
}

blob_exists_at_orphaned() {
  local bucket="$1"
  local uuid="$2"

  aws s3api head-object \
    --bucket "${bucket}" \
    --key "${ORPHANED_FOLDER}/${uuid}" \
    &>/dev/null
}

move_orphaned_blob() {
  local bucket="$1"
  local uuid="$2"

  local src="s3://${bucket}/${uuid}"
  local dst="s3://${bucket}/${ORPHANED_FOLDER}/${uuid}"

  if "${DRY_RUN}"; then
    echo "[DRY-RUN] aws s3 mv ${src} ${dst}"
    return 0
  fi

  # Skip if already moved
  if blob_exists_at_orphaned "${bucket}" "${uuid}"; then
    echo "[SKIP]    ${uuid} already in ${ORPHANED_FOLDER}/"
    return 0
  fi

  # Skip if source no longer exists (already cleaned up)
  if ! blob_exists_at_source "${bucket}" "${uuid}"; then
    echo "[MISSING] ${uuid} not found in bucket root — skipping"
    return 0
  fi

  if aws s3 mv "${src}" "${dst}" --only-show-errors; then
    echo "[MOVED]   ${uuid} → ${ORPHANED_FOLDER}/${uuid}"
  else
    echo "[FAILED]  ${uuid} → ${ORPHANED_FOLDER}/${uuid}" >&2
    return 1
  fi
}

run_orphan_migration() {
  local input_file="${INPUT_DIR}/orphaned_blobs.csv"

  # Count and compute total size (skip header)
  local count=0
  local total_bytes=0

  while IFS=, read -r uuid size _rest; do
    [[ "${uuid}" == "uuid" ]] && continue
    count=$((count + 1))
    total_bytes=$((total_bytes + size))
  done < "${input_file}"

  local total_size_gb
  total_size_gb="$(awk "BEGIN { printf \"%.2f\", ${total_bytes}/1073741824 }")"

  log_info "Orphaned blobs found: ${count} (${total_size_gb} GB)"

  if [[ "${count}" -eq 0 ]]; then
    log_success "No orphaned blobs to migrate."
    return 0
  fi

  if ! "${DRY_RUN}"; then
    confirm_move "${count}" "${total_size_gb}"
  else
    log_warning "DRY-RUN mode: no changes will be made to S3."
  fi

  log_info "Moving ${count} orphaned blobs to s3://${BUCKET}/${ORPHANED_FOLDER}/..."

  local moved=0
  local skipped=0
  local failed=0
  local missing=0

  while IFS=, read -r uuid _rest; do
    [[ "${uuid}" == "uuid" ]] && continue

    result=$(move_orphaned_blob "${BUCKET}" "${uuid}" 2>&1)
    echo "${result}"

    if   [[ "${result}" == *"[MOVED]"* ]];   then moved=$((moved + 1))
    elif [[ "${result}" == *"[SKIP]"* ]];    then skipped=$((skipped + 1))
    elif [[ "${result}" == *"[MISSING]"* ]]; then missing=$((missing + 1))
    elif [[ "${result}" == *"[DRY-RUN]"* ]]; then moved=$((moved + 1))
    else failed=$((failed + 1))
    fi
  done < "${input_file}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Orphan Migration Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  Moved:   %d\n"  "${moved}"
  printf "  Skipped: %d (already in orphaned/)\n" "${skipped}"
  printf "  Missing: %d (not found in root — already cleaned?)\n" "${missing}"
  printf "  Failed:  %d\n"  "${failed}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "${failed}" -gt 0 ]]; then
    log_error "${failed} blobs failed to move. Check output above."
    return 1
  fi

  log_success "Orphan migration complete."
  echo ""
  log_info "NEXT STEP: Run ./cleanup-orphans.sh when you are confident the orphaned blobs are no longer needed."
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  S3 Orphan Migration - Buildpacks CI"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  parse_args "$@"
  validate_prerequisites
  validate_s3_access

  log_info "Bucket:    s3://${BUCKET}/"
  log_info "Input dir: ${INPUT_DIR}"

  run_orphan_migration
}

main "$@"
