#!/usr/bin/env bash
set -euo pipefail

GIT_USER_EMAIL="${GIT_USER_EMAIL:-cf-buildpacks-eng@pivotal.io}"
GIT_USER_NAME="${GIT_USER_NAME:-CF Buildpacks Team CI Server}"

# Seed merged-builds-metadata from the builds git resource (including .git/).
# merged-builds-metadata is an output dir, so we need .git/ for commits and
# for the subsequent `put: builds` step to push.
rsync -a builds/ merged-builds-metadata/

pushd merged-builds-metadata >/dev/null
git config user.email "${GIT_USER_EMAIL}"
git config user.name  "${GIT_USER_NAME}"
popd >/dev/null

for stack_dir in *-builds-metadata; do
  # Guard against the glob expanding to its literal string when no dirs match.
  [[ -d "${stack_dir}" ]] || continue
  [[ "${stack_dir}" == "merged-builds-metadata" ]] && continue
  [[ -d "${stack_dir}/binary-builds-new" ]] || continue

  # Count new files with a dry-run BEFORE the real copy.
  # -v is required: without it rsync emits no per-file output and grep -c
  # always returns 0. The destination dir may not exist yet (first run), so
  # rsync lists it as "created directory" — grep -c '\.json$' filters that out.
  count=$(rsync -av --ignore-existing --dry-run \
    "${stack_dir}/binary-builds-new/" \
    "merged-builds-metadata/binary-builds-new/" 2>/dev/null | grep -c '\.json$' || true)

  echo "[merge] Copying JSON files from ${stack_dir} (${count} new file(s))..."
  rsync -a --ignore-existing \
    "${stack_dir}/binary-builds-new/" \
    "merged-builds-metadata/binary-builds-new/"
done

pushd merged-builds-metadata >/dev/null

# binary-builds-new/ may not exist if no stack dirs had any JSON files.
[[ -d binary-builds-new ]] || { echo "[merge] No binary-builds-new/ directory — nothing to commit"; exit 0; }

git add binary-builds-new/

if git diff --cached --quiet; then
  echo "[merge] No changes staged — all versions already present in builds repo"
else
  FILES=$(git diff --cached --name-only | tr '\n' ' ')
  git commit -m "Merge builds metadata: ${FILES}"
  echo "[merge] Committed merged builds metadata"
fi
popd >/dev/null
