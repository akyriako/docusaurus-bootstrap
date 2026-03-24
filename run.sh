#!/usr/bin/env bash
set -euo pipefail

: "${GITEA_HOST:?missing GITEA_HOST}"
: "${GITEA_TOKEN:?missing GITEA_TOKEN}"
: "${GIT_OWNER:?missing GIT_OWNER}"
: "${REPO_NAME:?missing REPO_NAME}"

GITEA_PROTOCOL="${GITEA_PROTOCOL:-https}"

SITE_NAME="${SITE_NAME:-$REPO_NAME}"
TEMPLATE="${TEMPLATE:-classic}"
WORKDIR="${WORKDIR:-/tmp/work}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
CREATE_UNDER_ORG="${CREATE_UNDER_ORG:-true}"
GIT_USERNAME="${GIT_USERNAME:-flux-bootstrap}"
GIT_EMAIL="${GIT_EMAIL:-bootstrap@local}"

BASE_URL="${GITEA_PROTOCOL}://${GITEA_HOST}"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "Scaffolding Docusaurus site..."
npx create-docusaurus@latest "$SITE_NAME" "$TEMPLATE" --package-manager npm

cd "$SITE_NAME"

echo "Initializing git..."
git init
git config user.name "$GIT_USERNAME"
git config user.email "$GIT_EMAIL"
git checkout -b "$DEFAULT_BRANCH"

git add .
git commit -m "Initial Docusaurus scaffold"

if [ "$CREATE_UNDER_ORG" = "true" ]; then
  echo "Creating org repository in Gitea..."
  curl -fsS \
    -H "Content-Type: application/json" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -X POST \
    "${BASE_URL}/api/v1/orgs/${GIT_OWNER}/repos" \
    -d "{
      \"name\": \"${REPO_NAME}\",
      \"default_branch\": \"${DEFAULT_BRANCH}\",
      \"private\": false,
      \"auto_init\": false
    }" || true
else
  echo "Creating user repository in Gitea..."
  curl -fsS \
    -H "Content-Type: application/json" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -X POST \
    "${BASE_URL}/api/v1/user/repos" \
    -d "{
      \"name\": \"${REPO_NAME}\",
      \"default_branch\": \"${DEFAULT_BRANCH}\",
      \"private\": false,
      \"auto_init\": false
    }" || true
fi

echo "Pushing to remote..."
git remote add origin "${BASE_URL}/${GIT_OWNER}/${REPO_NAME}.git"
git push -u origin "$DEFAULT_BRANCH"

echo "Done."