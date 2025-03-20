npm i

# Get affected projects using Nx
echo "$BASE"

COMMIT_HASH=$(git rev-parse @~~)
echo $COMMIT_HASH
CHANGED_APPS=$(npx nx show projects --affected --base=$COMMIT_HASH --head=test009 | tr '\n' ',')

echo "Changed projects: '$CHANGED_APPS'"

# Set prerelease flag based on branch
# if [[ ${{ github.ref }} == "refs/heads/develop" ]]; then
#     CZ_FLAGS="--prerelease alpha"
# elif [[ ${{ github.ref }} == "refs/heads/uat" ]]; then
#     CZ_FLAGS="--prerelease rc"
# fi

CZ_FLAGS="--prerelease alpha"

# shellcheck disable=SC2086
# Commitizen bump
# cz bump --changelog --yes ${CZ_FLAGS}
echo $CHANGED_APPS
if [[ "$CHANGED_APPS" == *"shared"* || "$CHANGED_APPS" == "a,b,c," ]]; then
    cz --config projects/a/.cz.json bump --yes ${CZ_FLAGS}
    cz --config projects/b/.cz.json bump --yes ${CZ_FLAGS}
    cz --config projects/c/.cz.json bump --yes ${CZ_FLAGS}
elif [[ "$CHANGED_APPS" == *"a"* ]]; then
    cz --config projects/a/.cz.json bump --yes ${CZ_FLAGS}
elif [[ "$CHANGED_APPS" == *"b"* ]]; then
    cz --config projects/b/.cz.json bump --yes ${CZ_FLAGS}
elif [[ "$CHANGED_APPS" == *"c"* ]]; then
    cz --config projects/c/.cz.json bump --yes ${CZ_FLAGS}
else
    echo 'No changes on applications. Not bumping...'
    exit 1
fi

# Remove trailing comma
CZ_FILES="${CHANGED_APPS%,}"

Loop through bumped projects and create individual tags
for FILE in $(echo "$CZ_FILES" | tr ',' ' '); do
    echo $FILE
    VERSION=$(jq -r ".commitizen.version" projects/$FILE/.cz.json)

    # shellcheck disable=SC2001
    RELEASE_VERSION=$(echo "${VERSION}" | sed 's/\(a\|b\|rc\)[0-9]\+$//')
    # shellcheck disable=SC2001
    PRERELEASE=$(echo "${VERSION}" | sed 's/v\([0-9]\+\.\?\)\{3\}\(a\|rc\)[0-9]*/\2/g')

    cz changelog --file-name "RELEASE_NOTES.md" "${VERSION}"

    # For RC and Production releases merge release notes from alpha and rc releases respectively
    if [[ "${PRERELEASE}" != "a" ]]; then
        git tag -l "${RELEASE_VERSION}a*" | sort > TAGS
        VERSION_COUNT=$(wc -l < TAGS)
        if [[ $VERSION_COUNT -ge 1 ]]; then
        FIRST_REV=$(head -n1 TAGS)
        LAST_REV=$(tail -n1 TAGS)
        cz changelog --file-name PRERELEASE_NOTES.md --merge-tags "${FIRST_REV}".."${LAST_REV}"
        sed '/^## /d' PRERELEASE_NOTES.md >> RELEASE_NOTES.md
        fi
    fi
done

cat CHANGELOG.md >> RELEASE_NOTES.md
cat -s RELEASE_NOTES.md > CHANGELOG.md

git add CHANGELOG.md
git commit --amend --no-edit

# git log
# git tag