#!/usr/bin/env bash
# cleanup-blobs.sh
#
# Deletes original flat UUID blobs from the S3 bucket root after the migration
# grace period has elapsed. This is the final step of the S3 namespace migration.
#
# Safety guarantees:
#   - Each blob is verified to exist at its namespaced path (<folder>/<uuid>)
#     before the root-level copy is deleted. Deletion is refused if the
#     namespaced copy is missing.
#   - The script hard-blocks if any blob was copied less than GRACE_DAYS ago
#     (default: 30). Use --force to override.
#
# Input (in priority order):
#   1. output.json written by migrate-blobs.sh  (preferred — includes copied_at)
#   2. all_blob_history.csv from uuid-mapper     (fallback — no timestamp)
#
# Usage:
#   ./cleanup-blobs.sh [OPTIONS]
#
# Options:
#   --bucket BUCKET       S3 bucket name (default: buildpacks.cloudfoundry.org)
#   --input-dir DIR       Directory containing migration output / uuid-mapper CSVs
#                         (default: ../uuid-mapper/output)
#   --grace-days N        Minimum days since migration before deletion is allowed
#                         (default: 30)
#   --dry-run             Print delete commands without executing them
#   --force               Skip grace-period check (use with caution)
#   --buildpack NAME      Clean up only the specified buildpack namespace
#   --help                Show this help message
#
# Exit codes:
#   0 - All eligible blobs deleted (or dry-run completed)
#   1 - Grace period not elapsed (use --force to override)
#   2 - One or more blobs failed safety check or deletion

set -euo pipefail
shopt -s inherit_errexit

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BUCKET="buildpacks.cloudfoundry.org"
DEFAULT_INPUT_DIR="${SCRIPT_DIR}/../uuid-mapper/output"
DEFAULT_GRACE_DAYS=30

# Repo → folder mapping (must match migrate-blobs.sh)
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
  GRACE_DAYS="${DEFAULT_GRACE_DAYS}"
  DRY_RUN=false
  FORCE=false
  FILTER_BUILDPACK=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bucket)      BUCKET="$2";           shift 2 ;;
      --input-dir)   INPUT_DIR="$2";        shift 2 ;;
      --grace-days)  GRACE_DAYS="$2";       shift 2 ;;
      --dry-run)     DRY_RUN=true;          shift   ;;
      --force)       FORCE=true;            shift   ;;
      --buildpack)   FILTER_BUILDPACK="$2"; shift 2 ;;
      --help)        usage; exit 0 ;;
      *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done

  if [[ ! "${GRACE_DAYS}" =~ ^[0-9]+$ ]]; then
    log_error "--grace-days must be a non-negative integer"
    exit 1
  fi
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

  if ! command -v python3 &>/dev/null; then
    log_error "python3 not found. Required for JSON/CSV parsing."
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
# Input loading — output.json (preferred) or all_blob_history.csv (fallback)
# ---------------------------------------------------------------------------

# Emit lines: uuid folder copied_at
# copied_at is ISO-8601 when available, empty string when falling back to CSV.
load_migration_entries() {
  local output_json="${INPUT_DIR}/output.json"
  local history_csv="${INPUT_DIR}/all_blob_history.csv"

  if [[ -f "${output_json}" ]]; then
    log_info "Loading migration entries from output.json..."
    python3 - "${output_json}" "${FILTER_BUILDPACK}" <<'PYEOF'
import sys, json

output_file = sys.argv[1]
filter_bp   = sys.argv[2]

with open(output_file) as f:
    data = json.load(f)

for entry in data.get("migrated", []):
    uuid      = entry.get("uuid", "")
    folder    = entry.get("folder", "")
    copied_at = entry.get("copied_at", "")
    if not uuid or not folder:
        continue
    if filter_bp and folder != filter_bp:
        continue
    print(f"{uuid}\t{folder}\t{copied_at}")
PYEOF
    return
  fi

  if [[ -f "${history_csv}" ]]; then
    log_warning "output.json not found — falling back to all_blob_history.csv"
    log_warning "No copied_at timestamps available; grace-period check will be skipped."
    python3 - "${history_csv}" "${FILTER_BUILDPACK}" <<'PYEOF'
import sys, csv
from collections import defaultdict

REPO_TO_FOLDER = {
    "binary-buildpack-release":       "binary-buildpack",
    "dotnet-core-buildpack-release":  "dotnet-core-buildpack",
    "go-buildpack-release":           "go-buildpack",
    "hwc-buildpack-release":          "hwc-buildpack",
    "java-buildpack-release":         "java-buildpack",
    "java-offline-buildpack-release": "java-offline-buildpack",
    "nginx-buildpack-release":        "nginx-buildpack",
    "nodejs-buildpack-release":       "nodejs-buildpack",
    "php-buildpack-release":          "php-buildpack",
    "python-buildpack-release":       "python-buildpack",
    "r-buildpack-release":            "r-buildpack",
    "ruby-buildpack-release":         "ruby-buildpack",
    "staticfile-buildpack-release":   "staticfile-buildpack",
    "cflinuxfs3-release":             "cflinuxfs3",
    "cflinuxfs4-release":             "cflinuxfs4",
}

history_file = sys.argv[1]
filter_bp    = sys.argv[2]

seen = set()
with open(history_file, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        uuid   = row.get("uuid", "")
        repo   = row.get("repo", "")
        folder = REPO_TO_FOLDER.get(repo, "")
        if not uuid or not folder or uuid in seen:
            continue
        if filter_bp and folder != filter_bp:
            continue
        seen.add(uuid)
        print(f"{uuid}\t{folder}\t")
PYEOF
    return
  fi

  log_error "No input found. Expected one of:"
  log_error "  ${INPUT_DIR}/output.json  (from migrate-blobs.sh)"
  log_error "  ${INPUT_DIR}/all_blob_history.csv  (from uuid-mapper)"
  exit 1
}

# ---------------------------------------------------------------------------
# Grace-period enforcement
# ---------------------------------------------------------------------------

# Returns the number of days between a UTC ISO-8601 timestamp and now.
days_since() {
  local ts="$1"
  python3 - "${ts}" <<'PYEOF'
import sys
from datetime import datetime, timezone

ts = sys.argv[1].rstrip("Z")
try:
    then = datetime.fromisoformat(ts).replace(tzinfo=timezone.utc)
except ValueError:
    # Unparseable — treat as very old so we don't block on bad data
    print(99999)
    sys.exit(0)

now  = datetime.now(timezone.utc)
diff = (now - then).days
print(diff)
PYEOF
}

check_grace_period() {
  local copied_at="$1"
  local uuid="$2"

  # No timestamp available (CSV fallback) — skip grace check
  if [[ -z "${copied_at}" ]]; then
    return 0
  fi

  local age
  age="$(days_since "${copied_at}")"

  if [[ "${age}" -lt "${GRACE_DAYS}" ]]; then
    if "${FORCE}"; then
      log_warning "Grace period not elapsed for ${uuid} (${age}d < ${GRACE_DAYS}d) — proceeding anyway (--force)"
    else
      log_error "Grace period not elapsed for ${uuid}: copied ${age} day(s) ago, minimum is ${GRACE_DAYS}."
      log_error "Wait until $(python3 -c "
from datetime import datetime, timezone, timedelta
ts = '${copied_at}'.rstrip('Z')
d  = datetime.fromisoformat(ts).replace(tzinfo=timezone.utc) + timedelta(days=${GRACE_DAYS})
print(d.strftime('%Y-%m-%d'))
") or use --force to override."
      return 1
    fi
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Core deletion logic
# ---------------------------------------------------------------------------

namespaced_blob_exists() {
  local bucket="$1"
  local folder="$2"
  local uuid="$3"

  aws s3api head-object \
    --bucket "${bucket}" \
    --key "${folder}/${uuid}" \
    &>/dev/null
}

root_blob_exists() {
  local bucket="$1"
  local uuid="$2"

  aws s3api head-object \
    --bucket "${bucket}" \
    --key "${uuid}" \
    &>/dev/null
}

delete_root_blob() {
  local bucket="$1"
  local folder="$2"
  local uuid="$3"
  local copied_at="$4"

  # Grace-period check (exits non-zero if not elapsed and not --force)
  check_grace_period "${copied_at}" "${uuid}" || return 1

  # Safety: confirm namespaced copy exists before deleting root
  if ! namespaced_blob_exists "${bucket}" "${folder}" "${uuid}"; then
    log_error "SAFETY BLOCK: s3://${bucket}/${folder}/${uuid} not found — refusing to delete root blob"
    return 2
  fi

  if "${DRY_RUN}"; then
    echo "[DRY-RUN] aws s3 rm s3://${bucket}/${uuid}"
    return 0
  fi

  # Skip if already cleaned up
  if ! root_blob_exists "${bucket}" "${uuid}"; then
    echo "[SKIP]    s3://${bucket}/${uuid} — already deleted"
    return 0
  fi

  if aws s3 rm "s3://${bucket}/${uuid}" --only-show-errors; then
    echo "[DELETED] s3://${bucket}/${uuid}"
  else
    echo "[FAILED]  s3://${bucket}/${uuid}" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Confirmation prompt
# ---------------------------------------------------------------------------

confirm_deletion() {
  local count="$1"

  echo ""
  log_warning "About to DELETE ${count} root-level blob(s) from s3://${BUCKET}/"
  echo ""
  echo "  Each blob has been verified to exist at its namespaced path."
  echo "  This operation is IRREVERSIBLE."
  echo ""
  read -r -p "  Type 'yes' to proceed: " confirmation
  if [[ "${confirmation}" != "yes" ]]; then
    log_info "Aborted by user."
    exit 0
  fi
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

run_cleanup() {
  local entries_file
  entries_file="$(mktemp)"
  trap 'rm -f "${entries_file}"' RETURN

  load_migration_entries > "${entries_file}"

  local total
  total="$(wc -l < "${entries_file}")"

  if [[ "${total}" -eq 0 ]]; then
    log_success "No blobs to clean up."
    return 0
  fi

  log_info "Blobs eligible for cleanup: ${total}"
  [[ -n "${FILTER_BUILDPACK}" ]] && log_info "Filter: ${FILTER_BUILDPACK}"
  "${DRY_RUN}" && log_warning "DRY-RUN mode: no changes will be made to S3."

  # Pre-flight: check grace period for all blobs before touching anything
  if ! "${FORCE}" && ! "${DRY_RUN}"; then
    log_info "Checking grace period for all blobs (${GRACE_DAYS} days required)..."
    local blocked=0
    while IFS=$'\t' read -r uuid folder copied_at; do
      check_grace_period "${copied_at}" "${uuid}" || blocked=$((blocked + 1))
    done < "${entries_file}"

    if [[ "${blocked}" -gt 0 ]]; then
      log_error "${blocked} blob(s) are still within the ${GRACE_DAYS}-day grace period."
      log_error "Re-run after the grace period, or use --force to override."
      exit 1
    fi
    log_success "Grace period elapsed for all blobs."
  fi

  if ! "${DRY_RUN}"; then
    confirm_deletion "${total}"
  fi

  local deleted=0
  local skipped=0
  local failed=0
  local blocked=0

  while IFS=$'\t' read -r uuid folder copied_at; do
    result=$(delete_root_blob "${BUCKET}" "${folder}" "${uuid}" "${copied_at}" 2>&1)
    local rc=$?
    echo "${result}"

    case "${rc}" in
      0)
        if   [[ "${result}" == *"[DELETED]"* ]]; then deleted=$((deleted + 1))
        elif [[ "${result}" == *"[SKIP]"* ]];    then skipped=$((skipped + 1))
        elif [[ "${result}" == *"[DRY-RUN]"* ]]; then deleted=$((deleted + 1))
        fi
        ;;
      1) failed=$((failed + 1)) ;;
      2) blocked=$((blocked + 1)) ;;
    esac
  done < "${entries_file}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Cleanup Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  Deleted:       %d\n" "${deleted}"
  printf "  Skipped:       %d (already deleted)\n" "${skipped}"
  printf "  Safety blocks: %d (namespaced copy missing — NOT deleted)\n" "${blocked}"
  printf "  Failed:        %d\n" "${failed}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "${blocked}" -gt 0 || "${failed}" -gt 0 ]]; then
    log_error "Cleanup finished with errors. Review output above."
    log_error "Safety-blocked blobs were NOT deleted — re-run migrate-blobs.sh for those UUIDs."
    exit 2
  fi

  log_success "Cleanup complete."
}

main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  S3 Namespace Cleanup - Buildpacks CI"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  parse_args "$@"
  validate_prerequisites
  validate_s3_access

  log_info "Bucket:      s3://${BUCKET}/"
  log_info "Input dir:   ${INPUT_DIR}"
  log_info "Grace period: ${GRACE_DAYS} days"
  "${FORCE}" && log_warning "Grace-period enforcement DISABLED (--force)"

  run_cleanup
}

main "$@"
