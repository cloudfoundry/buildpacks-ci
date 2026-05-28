#!/usr/bin/env bash
set -euo pipefail

GIT_USER_EMAIL="${GIT_USER_EMAIL:-cf-buildpacks-eng@pivotal.io}"
GIT_USER_NAME="${GIT_USER_NAME:-CF Buildpacks Team CI Server}"

rsync -a builds/ merged-builds-metadata/

pushd merged-builds-metadata >/dev/null
git config user.email "${GIT_USER_EMAIL}"
git config user.name  "${GIT_USER_NAME}"
popd >/dev/null

COPIED=0
for stack_dir in *-builds-metadata; do
  [[ "${stack_dir}" == "merged-builds-metadata" ]] && continue
  [[ -d "${stack_dir}/binary-builds-new" ]] || continue

  echo "[merge] Copying JSON files from ${stack_dir}..."
  rsync -a --ignore-existing \
    "${stack_dir}/binary-builds-new/" \
    "merged-builds-metadata/binary-builds-new/"

  count=$(find "${stack_dir}/binary-builds-new" -name "*.json" | wc -l)
  echo "[merge]   → ${count} file(s) copied"
  COPIED=$((COPIED + count))
done

if [[ "${COPIED}" -eq 0 ]]; then
  echo "[merge] WARNING: no per-stack JSON files found — nothing to commit"
  exit 0
fi

echo "[merge] Total files copied: ${COPIED}"

pushd merged-builds-metadata >/dev/null
git add binary-builds-new/

if git diff --cached --quiet; then
  echo "[merge] No changes staged — all versions already present in builds repo"
else
  FILES=$(git diff --cached --name-only | tr '\n' ' ')
  git commit -m "Merge builds metadata: ${FILES}"
  echo "[merge] Committed merged builds metadata"
fi
popd >/dev/null
