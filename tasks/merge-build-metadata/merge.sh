#!/usr/bin/env bash
# Merge build metadata from multiple stack builds into a single atomic git commit.
#
# This task runs after parallel stack build tasks (e.g., cflinuxfs4 and cflinuxfs5)
# that have SKIP_INDIVIDUAL_COMMIT=true set. It:
#   1. Seeds builds-merged from the builds git resource
#   2. Merges all stack-specific JSON files from stack*-builds-metadata inputs
#   3. Creates a single atomic commit with all stacks' metadata
#
# Inputs:
#   - builds: the git resource (latest state from GitHub)
#   - stack1-builds-metadata: builds-artifacts from first stack build
#   - stack2-builds-metadata: builds-artifacts from second stack build
#   - (can be extended to stack3, stack4, etc. for future stacks)
#
# Outputs:
#   - builds-merged: git repo with all stacks' JSON files, ready to push

set -euo pipefail

echo "[merge-task] Starting multi-stack metadata merge..."

# ── 1. Seed builds-merged from builds git resource ───────────────────────────
echo "[merge-task] Seeding builds-merged from builds git repo..."
rsync -a builds/ builds-merged/

# ── 2. Merge JSON files from all stack builds ────────────────────────────────
echo "[merge-task] Merging metadata from stack build tasks..."

# Find all stack*-builds-metadata input directories
for stack_dir in stack*-builds-metadata; do
  if [[ -d "${stack_dir}/binary-builds-new" ]]; then
    echo "[merge-task]   Merging from ${stack_dir}..."
    rsync -a "${stack_dir}/binary-builds-new/" builds-merged/binary-builds-new/
  else
    echo "[merge-task]   WARNING: ${stack_dir} has no binary-builds-new/ directory, skipping"
  fi
done

# ── 3. Verify merged files ───────────────────────────────────────────────────
echo "[merge-task] Verifying merged metadata files..."
cd builds-merged

# Stage all changes from rsync
echo "[merge-task] Staging changes..."
git add binary-builds-new/

# Check if there are any changes to commit
if git diff --cached --quiet; then
  echo "[merge-task] No changes to commit (builds already up-to-date)"
  exit 0
fi

CHANGED_FILES=$(git diff --cached --name-only | grep '\.json$' | wc -l)
echo "[merge-task] Found ${CHANGED_FILES} JSON file(s) to commit"

# ── 4. Create atomic commit with all stacks ──────────────────────────────────
echo "[merge-task] Creating atomic commit..."

git config user.email "cf-buildpacks-eng@pivotal.io"
git config user.name "CF Buildpacks Team CI Server"

# Extract dependency name and version from the first JSON file found
FIRST_JSON=$(git diff --cached --name-only | grep '\.json$' | head -1)
DEP_NAME=$(echo "${FIRST_JSON}" | sed 's|binary-builds-new/\([^/]*\)/.*|\1|')
VERSION=$(basename "${FIRST_JSON}" | sed 's/-cflinuxfs[0-9]*.json$//')

# Extract all unique stacks from changed JSON files
STACKS=$(git diff --cached --name-only | grep '\.json$' | \
         sed 's/.*-\(cflinuxfs[0-9]*\)\.json$/\1/' | \
         sort -u | \
         tr '\n' ',' | \
         sed 's/,$//')

# Commit with format: "Build <dep> - <version> - <stack1>,<stack2>"
COMMIT_MSG="Build ${DEP_NAME} - ${VERSION} - ${STACKS}"
git commit -m "${COMMIT_MSG}"

echo "[merge-task] Committed: ${COMMIT_MSG}"
echo "[merge-task] Merge complete!"
