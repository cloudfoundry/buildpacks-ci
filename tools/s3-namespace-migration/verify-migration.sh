#!/usr/bin/env bash
# verify-migration.sh
#
# Verifies that all current active BOSH blobs (from config/blobs.yml in each
# buildpack release repository) exist at their expected namespaced S3 paths.
#
# This script reads directly from the local buildpack release repositories
# rather than the uuid-mapper output, making it the authoritative post-migration
# health check.
#
# Checks performed:
#   1. Each UUID in config/blobs.yml exists at <folder_name>/<uuid> in S3
#   2. The SHA256 of the namespaced object matches the value in blobs.yml
#   3. The object size in S3 matches the size recorded in blobs.yml
#
# Usage:
#   ./verify-migration.sh [OPTIONS]
#
# Options:
#   --bucket BUCKET        S3 bucket name (default: buildpacks.cloudfoundry.org)
#   --releases-dir DIR     Directory containing buildpack release repos
#                          (default: ../../../../buildpacks-release)
#   --buildpack NAME       Verify only the specified namespace (folder_name)
#   --check-sha            Also verify SHA256 checksums (slower, requires download)
#   --help                 Show this help message
#
# Exit codes:
#   0 - All blobs verified successfully
#   1 - One or more blobs missing or mismatched

set -euo pipefail
shopt -s inherit_errexit

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BUCKET="buildpacks.cloudfoundry.org"
DEFAULT_RELEASES_DIR="${SCRIPT_DIR}/../../../../buildpacks-release"

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
  RELEASES_DIR="${DEFAULT_RELEASES_DIR}"
  FILTER_BUILDPACK=""
  CHECK_SHA=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bucket)       BUCKET="$2";           shift 2 ;;
      --releases-dir) RELEASES_DIR="$2";     shift 2 ;;
      --buildpack)    FILTER_BUILDPACK="$2"; shift 2 ;;
      --check-sha)    CHECK_SHA=true;        shift ;;
      --help)         usage; exit 0 ;;
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
    log_error "python3 not found. Required for parsing blobs.yml."
    exit 1
  fi

  if [[ ! -d "${RELEASES_DIR}" ]]; then
    log_error "Releases directory not found: ${RELEASES_DIR}"
    log_error "Use --releases-dir to specify the correct path."
    exit 1
  fi

  # Resolve to absolute path now that we've confirmed it exists
  RELEASES_DIR="$(cd "${RELEASES_DIR}" && pwd)"
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
# blobs.yml parsing (inline Python for YAML support without extra deps)
# ---------------------------------------------------------------------------

# Parse blobs.yml and emit: uuid folder_name expected_size expected_sha
parse_blobs_yml() {
  local blobs_yml="$1"
  local folder_name="$2"

  python3 - "${blobs_yml}" "${folder_name}" <<'PYEOF'
import sys
import yaml

blobs_file, folder = sys.argv[1], sys.argv[2]

with open(blobs_file, 'r') as f:
    data = yaml.safe_load(f) or {}

for _path, info in data.items():
    if not isinstance(info, dict):
        continue
    uuid = info.get('object_id') or info.get('blobstore_id', '')
    size = info.get('size', 0)
    sha  = info.get('sha', '') or info.get('sha256', '')
    # Normalise sha256: prefix
    sha = sha.replace('sha256:', '').strip()
    if uuid:
        print(f"{uuid} {folder} {size} {sha}")
PYEOF
}

# ---------------------------------------------------------------------------
# Verification logic
# ---------------------------------------------------------------------------

verify_blob_exists() {
  local bucket="$1"
  local folder="$2"
  local uuid="$3"
  local expected_size="$4"

  local meta
  meta=$(aws s3api head-object \
    --bucket "${bucket}" \
    --key "${folder}/${uuid}" \
    --output json 2>/dev/null) || {
    log_error "${folder}/${uuid}  — NOT FOUND in S3"
    return 1
  }

  local actual_size
  actual_size=$(echo "${meta}" | python3 -c "import sys,json; print(json.load(sys.stdin)['ContentLength'])")

  if [[ "${expected_size}" -gt 0 && "${actual_size}" != "${expected_size}" ]]; then
    log_error "${folder}/${uuid}  — SIZE MISMATCH (expected ${expected_size}, got ${actual_size})"
    return 1
  fi

  log_success "${folder}/${uuid}  (${actual_size} bytes)"
  return 0
}

verify_blob_sha() {
  local bucket="$1"
  local folder="$2"
  local uuid="$3"
  local expected_sha="$4"

  if [[ -z "${expected_sha}" ]]; then
    log_warning "${folder}/${uuid}  — no expected SHA, skipping checksum"
    return 0
  fi

  local tmp_file
  tmp_file="$(mktemp)"
  trap 'rm -f "${tmp_file}"' RETURN

  log_info "Downloading ${folder}/${uuid} for SHA verification..."
  aws s3 cp "s3://${bucket}/${folder}/${uuid}" "${tmp_file}" --quiet

  local actual_sha
  actual_sha="$(sha256sum "${tmp_file}" | awk '{print $1}')"

  if [[ "${actual_sha}" != "${expected_sha}" ]]; then
    log_error "${folder}/${uuid}  — SHA MISMATCH"
    log_error "  Expected: ${expected_sha}"
    log_error "  Actual:   ${actual_sha}"
    return 1
  fi

  log_success "${folder}/${uuid}  — SHA verified"
}

verify_release() {
  local release_dir="$1"
  local release_name
  release_name="$(basename "${release_dir}")"

  local blobs_yml="${release_dir}/config/blobs.yml"
  local final_yml="${release_dir}/config/final.yml"

  if [[ ! -f "${blobs_yml}" ]]; then
    log_warning "${release_name}: no config/blobs.yml — skipping"
    return 0
  fi

  # Extract folder_name from final.yml (falls back to release name without -release)
  local folder_name
  if [[ -f "${final_yml}" ]]; then
    folder_name=$(python3 - "${final_yml}" <<'PYEOF'
import sys, yaml
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f) or {}
opts = d.get('blobstore', {}).get('options', {})
print(opts.get('folder_name') or d.get('final_name', ''))
PYEOF
)
  fi

  if [[ -z "${folder_name}" ]]; then
    folder_name="${release_name%-release}"
  fi

  # Apply filter
  if [[ -n "${FILTER_BUILDPACK}" && "${folder_name}" != "${FILTER_BUILDPACK}" ]]; then
    return 0
  fi

  echo ""
  echo "  ┌─ ${release_name} → s3://${BUCKET}/${folder_name}/"

  local pass=0
  local fail=0

  while IFS=' ' read -r uuid folder expected_size expected_sha; do
    if verify_blob_exists "${BUCKET}" "${folder}" "${uuid}" "${expected_size}"; then
      pass=$((pass + 1))

      if "${CHECK_SHA}"; then
        verify_blob_sha "${BUCKET}" "${folder}" "${uuid}" "${expected_sha}" || fail=$((fail + 1))
      fi
    else
      fail=$((fail + 1))
    fi
  done < <(parse_blobs_yml "${blobs_yml}" "${folder_name}")

  echo "  └─ ${release_name}: ${pass} passed, ${fail} failed"

  [[ "${fail}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  S3 Namespace Migration Verification - Buildpacks CI"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  parse_args "$@"
  validate_prerequisites
  validate_s3_access

  log_info "Bucket:       s3://${BUCKET}/"
  log_info "Releases dir: ${RELEASES_DIR}"
  "${CHECK_SHA}" && log_info "SHA checks:   enabled (this will be slow)"
  [[ -n "${FILTER_BUILDPACK}" ]] && log_info "Filter:       ${FILTER_BUILDPACK}"

  local total_pass=0
  local total_fail=0
  local releases_checked=0

  for release_dir in "${RELEASES_DIR}"/*/; do
    [[ -d "${release_dir}" ]] || continue

    if verify_release "${release_dir}"; then
      total_pass=$((total_pass + 1))
    else
      total_fail=$((total_fail + 1))
    fi
    releases_checked=$((releases_checked + 1))
  done

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Verification Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  Releases checked: %d\n" "${releases_checked}"
  printf "  Passed:           %d\n" "${total_pass}"
  printf "  Failed:           %d\n" "${total_fail}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "${total_fail}" -gt 0 ]]; then
    log_error "Verification FAILED for ${total_fail} release(s)."
    log_error "Re-run migrate-blobs.sh to retry missing blobs."
    exit 1
  fi

  log_success "All blobs verified at namespaced S3 paths."
}

main "$@"
