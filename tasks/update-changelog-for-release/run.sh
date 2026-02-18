#!/usr/bin/env bash

set -euo pipefail

BUILDPACK_DIR="${PWD}/buildpack"
VERSION_FILE="${PWD}/version/version"

cd "${BUILDPACK_DIR}"

if [[ -n "${REPO_PRIVATE_KEY:-}" ]]; then
    eval "$(ssh-agent -s)"
    ssh-add - <<< "${REPO_PRIVATE_KEY}"
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"
fi

if [[ ! -f "${VERSION_FILE}" ]]; then
    echo "ERROR: Version file not found at ${VERSION_FILE}"
    exit 1
fi

VERSION=$(cat "${VERSION_FILE}")
echo "📝 Updating CHANGELOG for v${VERSION}"

if [[ ! -f CHANGELOG ]]; then
    echo "ERROR: CHANGELOG not found in buildpack directory"
    exit 1
fi

LAST_VERSION=$(head -n 1 CHANGELOG | awk '{print $1}' | sed 's/^v//')

if [[ -z "${LAST_VERSION}" ]]; then
    echo "WARNING: Could not extract last version from CHANGELOG, assuming no previous tags"
    LAST_VERSION_TAG=""
else
    LAST_VERSION_TAG="v${LAST_VERSION}"
    echo "Last version: ${LAST_VERSION_TAG}"
fi

echo "Fetching commits since ${LAST_VERSION_TAG:-beginning}..."

if [[ -n "${LAST_VERSION_TAG}" ]]; then
    if ! git rev-parse "${LAST_VERSION_TAG}" >/dev/null 2>&1; then
        echo "WARNING: Tag ${LAST_VERSION_TAG} not found, using all commits"
        COMMIT_RANGE="HEAD"
    else
        COMMIT_RANGE="${LAST_VERSION_TAG}..HEAD"
    fi
else
    COMMIT_RANGE="HEAD"
fi

should_skip_commit() {
    local subject="$1"
    local body="$2"
    
    # Skip merge commits
    if [[ "${subject}" =~ ^Merge\ (pull\ request|branch) ]]; then
        return 0
    fi
    
    # Skip version bump commits
    if [[ "${subject}" =~ ^[Bb]ump(s)?\ (to\ )?[0-9] ]] || \
       [[ "${subject}" =~ ^[Bb]ump\ version ]] || \
       [[ "${subject}" =~ ^Bump\ from\ .*\ to\ .* ]]; then
        return 0
    fi
    
    # Skip CI/config/meta commits
    if [[ "${subject}" =~ ^Updating\ github-config ]] || \
       [[ "${subject}" =~ ^\[ci\ skip\] ]] || \
       [[ "${subject}" =~ ^Update\ \.github/ ]] || \
       [[ "${subject}" =~ ^[Dd]elete.*\.yml$ ]] || \
       [[ "${subject}" =~ ^[Ff]ix.*template ]] || \
       [[ "${subject}" =~ ^[Dd]elete\ release ]] || \
       [[ "${subject}" =~ ^consolidate.*branch ]]; then
        return 0
    fi
    
    # Skip test framework updates (switchblade, brats, etc.)
    if [[ "${subject}" =~ ^[Aa]dopt.*switchblade ]] || \
       [[ "${subject}" =~ ^[Uu]pgrade.*[Ss]witchblade ]] || \
       [[ "${subject}" =~ ^[Bb]ump\ switchblade ]] || \
       [[ "${subject}" =~ ^[Uu]pdate.*brats ]]; then
        return 0
    fi
    
    # Skip test-only commits (unless they're dependency updates)
    if [[ "${subject}" =~ [Rr]emove.*test ]] || \
       [[ "${subject}" =~ ^[Uu]pdate.*test ]] || \
       [[ "${subject}" =~ [Dd]elete.*test ]]; then
        if [[ ! "${body}" =~ for\ stack\(s\) ]]; then
            return 0
        fi
    fi
    
    # Skip internal tooling updates
    if [[ "${subject}" =~ ^[Cc]heck\ for\ CF\ CLI ]] || \
       [[ "${subject}" =~ ^[Aa]dd\ check\ for ]]; then
        return 0
    fi
    
    # Skip empty commits or commits with only whitespace subject
    if [[ -z "${subject// }" ]]; then
        return 0
    fi
    
    # Keep this commit
    return 1
}

COMMIT_HASHES=$(git log --pretty=format:'%H' ${COMMIT_RANGE})

if [[ -z "${COMMIT_HASHES}" ]]; then
    echo "WARNING: No commits found since ${LAST_VERSION_TAG:-beginning}"
    COMMIT_ENTRIES=""
else
    COMMIT_ENTRIES=""
    declare -A SEEN_SUBJECTS
    
    while IFS= read -r hash; do
        SUBJECT=$(git log --pretty=format:'%s' -n 1 "${hash}")
        BODY=$(git log --pretty=format:'%b' -n 1 "${hash}")
        
        # Skip filtered commits
        if should_skip_commit "${SUBJECT}" "${BODY}"; then
            echo "  Skipping: ${SUBJECT}"
            continue
        fi
        
        # Skip duplicate subjects (keeps first occurrence)
        if [[ -n "${SEEN_SUBJECTS[${SUBJECT}]:-}" ]]; then
            echo "  Skipping duplicate: ${SUBJECT}"
            continue
        fi
        SEEN_SUBJECTS["${SUBJECT}"]=1
        
        FILTERED_BODY=""
        while IFS= read -r line; do
            if [[ ! "${line}" =~ ^Signed-off-by: ]] && [[ ! "${line}" =~ ^Co-authored-by: ]]; then
                FILTERED_BODY="${FILTERED_BODY}${line}"$'\n'
            fi
        done <<< "${BODY}"
        
        FILTERED_BODY=$(echo "${FILTERED_BODY}" | sed -e :a -e '/^\s*$/d;N;ba')
        
        ENTRY="* ${SUBJECT}"
        if [[ -n "${FILTERED_BODY}" ]]; then
            INDENTED_BODY=$(echo "${FILTERED_BODY}" | sed 's/^/  /')
            ENTRY="${ENTRY}"$'\n'"${INDENTED_BODY}"
        fi
        
        echo "  Including: ${SUBJECT}"
        
        if [[ -n "${COMMIT_ENTRIES}" ]]; then
            COMMIT_ENTRIES="${COMMIT_ENTRIES}"$'\n\n'"${ENTRY}"
        else
            COMMIT_ENTRIES="${ENTRY}"
        fi
    done <<< "${COMMIT_HASHES}"
fi

DATE=$(date '+%b %d, %Y')
HEADING="v${VERSION} ${DATE}"
SEPARATOR=$(printf '=%.0s' $(seq 1 ${#HEADING}))

NEW_SECTION="${HEADING}"$'\n'"${SEPARATOR}"$'\n\n'
if [[ -n "${COMMIT_ENTRIES}" ]]; then
    NEW_SECTION="${NEW_SECTION}${COMMIT_ENTRIES}"$'\n\n\n'
else
    NEW_SECTION="${NEW_SECTION}\n"
fi

TEMP_CHANGELOG=$(mktemp)
echo -n "${NEW_SECTION}" > "${TEMP_CHANGELOG}"
cat CHANGELOG >> "${TEMP_CHANGELOG}"
mv "${TEMP_CHANGELOG}" CHANGELOG

echo "✅ CHANGELOG updated with ${VERSION} section"

git config user.email "cf-buildpacks-eng@pivotal.io"
git config user.name "CF Buildpacks Team CI Server"

git add CHANGELOG
git commit -m "[ci skip] Update CHANGELOG for v${VERSION}"

NEW_REF=$(git rev-parse HEAD)
echo "${NEW_REF}" > .git/ref

echo "✅ Committed CHANGELOG update (${NEW_REF})"
echo "✅ Updated .git/ref for GitHub release tagging"
