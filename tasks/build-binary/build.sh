#!/usr/bin/env bash
# Stack-agnostic build script for the Go binary-builder.
#
# Responsibilities:
#   1. Compile binary-builder from source (Go must be available in the container image).
#   2. Run: binary-builder build --stack $STACK --source-file source/data.json --stacks-dir binary-builder/stacks
#   3. Read the JSON summary from the output file.
#   4. Move the artifact from CWD to artifacts/.
#   5. Write builds-artifacts/binary-builds-new/<dep>/<dep>-<version>-<stack>.json
#   6. Write dep-metadata/<artifact>_metadata.json
#   7. Optionally commit the builds-artifacts changes to git (when SKIP_COMMIT != true).
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# ── 1. Compile binary-builder ─────────────────────────────────────────────────
echo "[task] Compiling binary-builder..."
pushd binary-builder >/dev/null
go build -buildvcs=false -o /usr/local/bin/binary-builder ./cmd/binary-builder
popd >/dev/null
echo "[task] binary-builder compiled successfully"

# ── 2. Run the builder ────────────────────────────────────────────────────────
DEP_NAME=$(jq -r '.source.name' source/data.json)
echo "[task] Building ${DEP_NAME} for stack ${STACK}..."

# binary-builder writes the artifact to CWD and the JSON summary to a file.
# Build subprocess output (compiler, make, etc.) flows to stdout/stderr and is
# visible in the build log without corrupting the structured JSON output file.
SUMMARY_FILE="/tmp/binary-builder-summary.json"
binary-builder build \
  --stack "${STACK}" \
  --source-file source/data.json \
  --stacks-dir binary-builder/stacks \
  --output-file "${SUMMARY_FILE}"

echo "[task] Build complete. Summary:"
jq . "${SUMMARY_FILE}" >&2

# ── 3. Extract fields from the summary ───────────────────────────────────────
ARTIFACT_FILE=$(jq -r '.artifact_path'   "${SUMMARY_FILE}")
VERSION=$(jq -r '.version'               "${SUMMARY_FILE}")
SHA256=$(jq -r '.sha256 // ""'           "${SUMMARY_FILE}")
URL=$(jq -r '.url // ""'                 "${SUMMARY_FILE}")

echo "[task] Artifact: ${ARTIFACT_FILE}"

# ── 4. Move artifact to outputs/artifacts/ ────────────────────────────────────
mkdir -p artifacts
if [[ -f "${ARTIFACT_FILE}" ]]; then
  mv "${ARTIFACT_FILE}" "artifacts/${ARTIFACT_FILE}"
  echo "[task] Artifact moved to artifacts/${ARTIFACT_FILE}"
else
  # URL-passthrough deps (e.g. miniconda) set URL directly — no file to move.
  echo "[task] No artifact file (URL-passthrough dep), skipping move"
fi

# ── 5. Write builds-artifacts JSON ───────────────────────────────────────────
BUILDS_DIR="builds-artifacts/binary-builds-new/${DEP_NAME}"
mkdir -p "${BUILDS_DIR}"
BUILDS_FILE="${BUILDS_DIR}/${DEP_NAME}-${VERSION}-${STACK}.json"

jq '{
  url:              (.url // ""),
  sha256:           (.sha256 // ""),
  source:           (.source // {}),
  source_sha256:    (.source.sha256 // ""),
  sub_dependencies: (.sub_dependencies // {})
} + if .git_commit_sha then {git_commit_sha: .git_commit_sha} else {} end' \
  "${SUMMARY_FILE}" > "${BUILDS_FILE}"

echo "[task] Wrote builds-artifacts to ${BUILDS_FILE}"

# ── 6. Write dep-metadata JSON ───────────────────────────────────────────────
# Format mirrors the Ruby builder's out_data.to_json output:
#   version, source, url, sha256 (+ git_commit_sha and sub_dependencies when present).
# Do NOT add extra fields (name, uri, source_sha256) that Ruby doesn't write.
mkdir -p dep-metadata
DEP_META_FILE="dep-metadata/${ARTIFACT_FILE}_metadata.json"

jq '{
  version:          .version,
  source:           (.source // {}),
  url:              (.url // ""),
  sha256:           (.sha256 // "")
} + if (.git_commit_sha and .git_commit_sha != "") then {git_commit_sha: .git_commit_sha} else {} end
  + if (.sub_dependencies | length) > 0 then {sub_dependencies: .sub_dependencies} else {} end' \
  "${SUMMARY_FILE}" > "${DEP_META_FILE}"

echo "[task] Wrote dep-metadata to ${DEP_META_FILE}"

# ── 7. Git commit builds-artifacts (unless SKIP_COMMIT=true) ─────────────────
if [[ "${SKIP_COMMIT:-}" == "true" ]]; then
  echo "[task] SKIP_COMMIT=true — skipping git commit"
  exit 0
fi

echo "[task] Committing builds-artifacts..."
pushd builds-artifacts >/dev/null
git config user.email "cf-buildpacks-eng@pivotal.io"
git config user.name  "CF Buildpacks Team CI Server"
git add .

# Safe-commit: only commit if there are staged changes.
if git diff --cached --quiet; then
  echo "[task] No changes to commit in builds-artifacts"
else
  git commit -m "Build ${DEP_NAME} - ${VERSION} - ${STACK}"
  echo "[task] Committed builds-artifacts"
fi
popd >/dev/null
