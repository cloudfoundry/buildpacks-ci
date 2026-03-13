#!/usr/bin/env bash
# migrate-blobs.sh
#
# Copies BOSH blob UUIDs from the S3 bucket root into per-buildpack
# namespaced folders as described in the S3 Bucket Namespacing RFC.
#
# Prerequisites:
#   - AWS CLI configured with access to the target bucket
#   - uuid-mapper output CSVs in the input directory
#     (run: cd tools/uuid-mapper && ./mapper.py --no-serve)
#
# Usage:
#   ./migrate-blobs.sh [OPTIONS]
#
# Options:
#   --bucket BUCKET       S3 bucket name (default: buildpacks.cloudfoundry.org)
#   --input-dir DIR       Directory containing uuid-mapper CSV output
#                         (default: ../uuid-mapper/output)
#   --output-dir DIR      Directory to write output.json (default: ../uuid-mapper/output)
#   --dry-run             Print copy commands without executing them
#   --buildpack NAME      Migrate only the specified buildpack namespace
#   --help                Show this help message

set -euo pipefail
shopt -s inherit_errexit

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BUCKET="buildpacks.cloudfoundry.org"
DEFAULT_INPUT_DIR="${SCRIPT_DIR}/../uuid-mapper/output"
DEFAULT_OUTPUT_DIR="${SCRIPT_DIR}/../uuid-mapper/output"

# Mapping: BOSH release repo name → S3 folder_name (= final_name in config/final.yml)
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
  OUTPUT_DIR="${DEFAULT_OUTPUT_DIR}"
  DRY_RUN=false
  FILTER_BUILDPACK=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bucket)      BUCKET="$2";           shift 2 ;;
      --input-dir)   INPUT_DIR="$2";        shift 2 ;;
      --output-dir)  OUTPUT_DIR="$2";       shift 2 ;;
      --dry-run)     DRY_RUN=true;          shift   ;;
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

  if [[ ! -f "${INPUT_DIR}/all_blob_history.csv" ]]; then
    log_error "Missing: ${INPUT_DIR}/all_blob_history.csv"
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

# Build a mapping of uuid → folder_name from all_blob_history.csv
# CSV format: uuid,filename,size,sha,repo,commit,date,author,tags
build_uuid_to_folder_map() {
  local input_file="${INPUT_DIR}/all_blob_history.csv"
  local map_file="${INPUT_DIR}/.uuid_to_folder_map.tmp"

  log_info "Building UUID → folder mapping from ${input_file}..." >&2

  # Clear existing map
  : > "${map_file}"

  local total=0
  local mapped=0
  local skipped=0

  while IFS=, read -r uuid _filename _size _sha repo _rest; do
    # Skip CSV header
    [[ "${uuid}" == "uuid" ]] && continue

    total=$((total + 1))

    local folder="${REPO_TO_FOLDER[${repo}]:-}"
    if [[ -z "${folder}" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    # Apply buildpack filter if specified
    if [[ -n "${FILTER_BUILDPACK}" && "${folder}" != "${FILTER_BUILDPACK}" ]]; then
      continue
    fi

    echo "${uuid} ${folder}" >> "${map_file}"
    mapped=$((mapped + 1))
  done < "${input_file}"

  # Deduplicate: keep unique uuid→folder pairs (a UUID may appear in many commits)
  sort -u "${map_file}" -o "${map_file}"

  log_info "Total history entries: ${total}" >&2
  log_info "Entries skipped (unknown repo): ${skipped}" >&2
  log_success "Unique UUID → folder mappings: $(wc -l < "${map_file}")" >&2

  # Only the file path goes to stdout — callers capture this with $()
  echo "${map_file}"
}

# Check whether a blob already exists at its target namespaced path
blob_exists_at_target() {
  local bucket="$1"
  local folder="$2"
  local uuid="$3"

  aws s3api head-object \
    --bucket "${bucket}" \
    --key "${folder}/${uuid}" \
    &>/dev/null
}

# Copy a single blob from root to its namespaced folder.
# Prints a tab-separated result line: STATUS<TAB>uuid<TAB>folder<TAB>timestamp
copy_blob() {
  local bucket="$1"
  local folder="$2"
  local uuid="$3"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local src="s3://${bucket}/${uuid}"
  local dst="s3://${bucket}/${folder}/${uuid}"

  if "${DRY_RUN}"; then
    echo "[DRY-RUN] aws s3 cp ${src} ${dst}"
    return 0
  fi

  # Skip if already migrated
  if blob_exists_at_target "${bucket}" "${folder}" "${uuid}"; then
    echo "[SKIP]	${uuid}	${folder}	${timestamp}"
    return 0
  fi

  if aws s3 cp "${src}" "${dst}" --only-show-errors; then
    echo "[COPIED]	${uuid}	${folder}	${timestamp}"
  else
    echo "[FAILED]	${uuid}	${folder}	${timestamp}" >&2
    return 1
  fi
}

# Run all copies sequentially
run_migration() {
  local map_file="$1"
  local total
  total="$(wc -l < "${map_file}")"

  log_info "Starting migration of ${total} blobs to s3://${BUCKET}/..."
  "${DRY_RUN}" && log_warning "DRY-RUN mode: no changes will be made to S3."

  local success=0
  local failed=0
  local skipped=0

  # Collect migrated entries for output.json (skipped in dry-run mode)
  local results_file=""
  if ! "${DRY_RUN}"; then
    results_file="$(mktemp)"
    trap 'rm -f "${results_file}"' RETURN
  fi

  while IFS=' ' read -r uuid folder; do
    result=$(copy_blob "${BUCKET}" "${folder}" "${uuid}" 2>&1)
    echo "${result}"

    if [[ "${result}" == *$'\t'* ]]; then
      # Structured result line: STATUS<TAB>uuid<TAB>folder<TAB>timestamp
      local status uuid_out folder_out ts
      IFS=$'\t' read -r status uuid_out folder_out ts <<< "${result}"
      case "${status}" in
        "[COPIED]") success=$((success + 1)); [[ -n "${results_file}" ]] && echo "${uuid_out} ${folder_out} ${ts}" >> "${results_file}" ;;
        "[SKIP]")   skipped=$((skipped + 1)); [[ -n "${results_file}" ]] && echo "${uuid_out} ${folder_out} ${ts}" >> "${results_file}" ;;
        *)          failed=$((failed + 1)) ;;
      esac
    elif [[ "${result}" == *"[DRY-RUN]"* ]]; then
      success=$((success + 1))
    else
      failed=$((failed + 1))
    fi
  done < "${map_file}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Migration Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  Copied:  %d\n"  "${success}"
  printf "  Skipped: %d (already at destination)\n" "${skipped}"
  printf "  Failed:  %d\n"  "${failed}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "${failed}" -gt 0 ]]; then
    log_error "${failed} blobs failed to copy. Check output above for details."
    return 1
  fi

  if ! "${DRY_RUN}"; then
    write_output_json "${results_file}"
  fi

  log_success "Migration complete."
}

# Write output.json recording every blob that was successfully migrated.
# This file is consumed by cleanup-blobs.sh to know what to clean up and when.
write_output_json() {
  local results_file="$1"
  local output_file="${OUTPUT_DIR}/output.json"
  local migrated_at
  migrated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  mkdir -p "${OUTPUT_DIR}"

  # Build JSON array of migrated entries
  local entries=""
  while IFS=' ' read -r uuid folder copied_at; do
    [[ -z "${uuid}" ]] && continue
    if [[ -n "${entries}" ]]; then
      entries="${entries},"
    fi
    entries="${entries}
    {\"uuid\":\"${uuid}\",\"folder\":\"${folder}\",\"copied_at\":\"${copied_at}\"}"
  done < "${results_file}"

  cat > "${output_file}" <<EOF
{
  "migrated_at": "${migrated_at}",
  "bucket": "${BUCKET}",
  "migrated": [${entries}
  ]
}
EOF

  log_success "Migration output written to: ${output_file}"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  S3 Namespace Migration - Buildpacks CI"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  parse_args "$@"
  validate_prerequisites
  validate_s3_access

  log_info "Bucket:     s3://${BUCKET}/"
  log_info "Input dir:  ${INPUT_DIR}"
  log_info "Output dir: ${OUTPUT_DIR}"
  [[ -n "${FILTER_BUILDPACK}" ]] && log_info "Filter:     ${FILTER_BUILDPACK}"

  local map_file
  map_file="$(build_uuid_to_folder_map)"

  run_migration "${map_file}"
}

main "$@"
