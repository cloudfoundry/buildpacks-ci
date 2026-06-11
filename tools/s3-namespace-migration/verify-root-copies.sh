#!/usr/bin/env bash
# verify-root-copies.sh
#
# Verifies that every known root-level UUID blob has been copied to its
# expected namespaced S3 path (<folder>/<uuid>). This is the pre-cleanup check
# for the S3 namespace migration.
#
# Input:
#   - all_blob_history.csv from uuid-mapper, used for UUID → folder mapping
#   - s3_uuid_files.csv from uuid-mapper, used to limit verification to UUIDs
#     that were seen at the bucket root when uuid-mapper was last run
#
# Usage:
#   ./verify-root-copies.sh [OPTIONS]
#
# Options:
#   --bucket BUCKET       S3 bucket name (default: buildpacks.cloudfoundry.org)
#   --input-dir DIR       Directory containing uuid-mapper CSV output
#                         (default: ../uuid-mapper/output)
#   --buildpack NAME      Verify only the specified buildpack namespace
#   --help                Show this help message
#
# Exit codes:
#   0 - All root-level mapped blobs have namespaced copies
#   1 - One or more namespaced copies are missing, or input is invalid

set -euo pipefail
shopt -s inherit_errexit

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BUCKET="buildpacks.cloudfoundry.org"
DEFAULT_INPUT_DIR="${SCRIPT_DIR}/../uuid-mapper/output"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

log_info()    { echo "[INFO]    $*"; }
log_success() { echo "[OK]      $*"; }
log_warning() { echo "[WARNING] $*"; }
log_error()   { echo "[FAIL]    $*" >&2; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

parse_args() {
  BUCKET="${DEFAULT_BUCKET}"
  INPUT_DIR="${DEFAULT_INPUT_DIR}"
  FILTER_BUILDPACK=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bucket)      BUCKET="$2";           shift 2 ;;
      --input-dir)   INPUT_DIR="$2";        shift 2 ;;
      --buildpack)   FILTER_BUILDPACK="$2"; shift 2 ;;
      --help)        usage; exit 0 ;;
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

  if ! command -v python3 &>/dev/null; then
    log_error "python3 not found. Required for CSV parsing."
    exit 1
  fi

  if [[ ! -f "${INPUT_DIR}/all_blob_history.csv" ]]; then
    log_error "Missing: ${INPUT_DIR}/all_blob_history.csv"
    log_error "Run the uuid-mapper tool first:"
    log_error "  cd tools/uuid-mapper && ./mapper.py --no-serve"
    exit 1
  fi

  if [[ ! -f "${INPUT_DIR}/s3_uuid_files.csv" ]]; then
    log_warning "Missing: ${INPUT_DIR}/s3_uuid_files.csv"
    log_warning "Falling back to all UUIDs in all_blob_history.csv."
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
# Input loading
# ---------------------------------------------------------------------------

# Emits tab-separated lines: uuid folder filename
load_expected_root_copies() {
  python3 - "${INPUT_DIR}" "${FILTER_BUILDPACK}" <<'PYEOF'
import csv
import sys
from pathlib import Path

input_dir = Path(sys.argv[1])
filter_bp = sys.argv[2]

repo_to_folder = {
    "binary-buildpack-release": "binary-buildpack",
    "dotnet-core-buildpack-release": "dotnet-core-buildpack",
    "go-buildpack-release": "go-buildpack",
    "hwc-buildpack-release": "hwc-buildpack",
    "java-buildpack-release": "java-buildpack",
    "java-offline-buildpack-release": "java-offline-buildpack",
    "nginx-buildpack-release": "nginx-buildpack",
    "nodejs-buildpack-release": "nodejs-buildpack",
    "php-buildpack-release": "php-buildpack",
    "python-buildpack-release": "python-buildpack",
    "r-buildpack-release": "r-buildpack",
    "ruby-buildpack-release": "ruby-buildpack",
    "staticfile-buildpack-release": "staticfile-buildpack",
    "cflinuxfs3-release": "cflinuxfs3",
    "cflinuxfs4-release": "cflinuxfs4",
}

root_uuids = None
s3_file = input_dir / "s3_uuid_files.csv"
if s3_file.exists():
    root_uuids = set()
    with s3_file.open(newline="") as f:
        for row in csv.DictReader(f):
            uuid = row.get("uuid", "").strip()
            if uuid:
                root_uuids.add(uuid)

entries = []
with (input_dir / "all_blob_history.csv").open(newline="") as f:
    for row in csv.DictReader(f):
        uuid = row.get("uuid", "").strip()
        repo = row.get("repo", "").strip()
        folder = repo_to_folder.get(repo, "")
        if not uuid or not folder:
            continue
        if root_uuids is not None and uuid not in root_uuids:
            continue
        if filter_bp and folder != filter_bp:
            continue
        entries.append({
            "uuid": uuid,
            "folder": folder,
            "filename": row.get("filename", "").strip(),
            "date": row.get("date", ""),
        })

# Deduplicate to one expected destination per UUID. Sort newest first to match
# migration-plan behavior for repeated history entries.
entries.sort(key=lambda e: (e["uuid"], e["date"]), reverse=True)
seen = set()
for entry in entries:
    uuid = entry["uuid"]
    if uuid in seen:
        continue
    seen.add(uuid)
    print(f'{uuid}\t{entry["folder"]}\t{entry["filename"]}')
PYEOF
}

# ---------------------------------------------------------------------------
# Verification logic
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

verify_expected_copy() {
  local bucket="$1"
  local uuid="$2"
  local folder="$3"
  local filename="$4"

  if namespaced_blob_exists "${bucket}" "${folder}" "${uuid}"; then
    echo "[OK]      ${uuid} → ${folder}/${uuid}"
    return 0
  fi

  echo "[MISSING] ${uuid} → ${folder}/${uuid}  (${filename:-unknown filename})"
  return 1
}

run_verification() {
  local entries_file
  entries_file="$(mktemp)"
  trap 'rm -f "${entries_file}"' RETURN

  load_expected_root_copies > "${entries_file}"

  local total
  total="$(wc -l < "${entries_file}")"

  if [[ "${total}" -eq 0 ]]; then
    log_success "No mapped root-level blobs found to verify."
    return 0
  fi

  log_info "Mapped root-level blobs to verify: ${total}"
  [[ -n "${FILTER_BUILDPACK}" ]] && log_info "Filter: ${FILTER_BUILDPACK}"

  local passed=0
  local missing=0

  while IFS=$'\t' read -r uuid folder filename; do
    if verify_expected_copy "${BUCKET}" "${uuid}" "${folder}" "${filename}"; then
      passed=$((passed + 1))
    else
      missing=$((missing + 1))
    fi
  done < "${entries_file}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Root Copy Verification Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  Verified: %d\n" "${passed}"
  printf "  Missing:  %d\n" "${missing}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "${missing}" -gt 0 ]]; then
    log_error "${missing} root-level blob(s) are missing namespaced copies."
    log_error "Re-run migrate-blobs.sh, then run this check again before cleanup."
    exit 1
  fi

  log_success "All mapped root-level blobs have namespaced copies."
}

main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  S3 Root Copy Verification - Buildpacks CI"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  parse_args "$@"
  validate_prerequisites
  validate_s3_access

  log_info "Bucket:    s3://${BUCKET}/"
  log_info "Input dir: ${INPUT_DIR}"

  run_verification
}

main "$@"
