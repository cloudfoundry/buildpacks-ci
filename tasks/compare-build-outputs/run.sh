#!/usr/bin/env bash
# buildpacks-ci/tasks/compare-build-outputs/run.sh
#
# Tier 4 shadow-run compare task.
# Diffs the dep-metadata JSON produced by the Ruby builder against the Go
# builder. Used in the shadow pipeline to detect any divergence before cutover.
#
# Inputs (Concourse resources):
#   ruby-dep-metadata/   — dep-metadata output from build-binary-new-cflinuxfs4 task
#   go-dep-metadata/     — dep-metadata output from build-binary task (SKIP_COMMIT=true)

set -euo pipefail

# Install jq (alpine base image)
if ! command -v jq &>/dev/null; then
  apk add --no-cache jq > /dev/null 2>&1
fi

ruby_json=$(ls ruby-dep-metadata/*.json 2>/dev/null | head -1)
go_json=$(ls go-dep-metadata/*.json     2>/dev/null | head -1)

if [[ -z "${ruby_json}" ]]; then
  echo "ERROR: no JSON file found in ruby-dep-metadata/"
  exit 1
fi
if [[ -z "${go_json}" ]]; then
  echo "ERROR: no JSON file found in go-dep-metadata/"
  exit 1
fi

echo "Comparing:"
echo "  Ruby: ${ruby_json}"
echo "  Go:   ${go_json}"

mismatches=0

# ── Field-by-field comparison ─────────────────────────────────────────────────

for field in version "source.url" "source.sha256" "source.sha512" "source.md5" url sha256; do
  ruby_val=$(jq -r ".${field} // empty" "${ruby_json}" 2>/dev/null)
  go_val=$(jq -r   ".${field} // empty" "${go_json}"   2>/dev/null)
  if [[ "${ruby_val}" != "${go_val}" ]]; then
    echo "MISMATCH: .${field}"
    echo "  Ruby: ${ruby_val}"
    echo "  Go:   ${go_val}"
    mismatches=$((mismatches + 1))
  fi
done

# ── sub_dependencies ──────────────────────────────────────────────────────────

ruby_subdeps=$(jq -r '.sub_dependencies // {} | to_entries[] | "\(.key)=\(.value.version)"' \
  "${ruby_json}" 2>/dev/null | sort)
go_subdeps=$(jq -r   '.sub_dependencies // {} | to_entries[] | "\(.key)=\(.value.version)"' \
  "${go_json}"   2>/dev/null | sort)

if [[ "${ruby_subdeps}" != "${go_subdeps}" ]]; then
  echo "MISMATCH: sub_dependencies"
  diff <(echo "${ruby_subdeps}") <(echo "${go_subdeps}") || true
  mismatches=$((mismatches + 1))
fi

# ── Result ───────────────────────────────────────────────────────────────────

if [[ "${mismatches}" -gt 0 ]]; then
  echo ""
  echo "Shadow run FAILED: ${mismatches} mismatch(es) between Ruby and Go builder outputs"
  exit 1
fi

echo ""
echo "Shadow run PASSED: Ruby and Go builder outputs are identical"
