#!/usr/bin/env bash
set -euo pipefail

: "${GITEA_HOST:?missing GITEA_HOST}"
: "${GITEA_TOKEN:?missing GITEA_TOKEN}"
: "${GIT_OWNER:?missing GIT_OWNER}"
: "${REPO_NAME:?missing REPO_NAME}"
: "${REGISTRY:?missing REGISTRY}"
: "${REGISTRY_ORG:?missing REGISTRY_ORG}"
: "${EXPOSE_URL:?missing EXPOSE_URL}"
: "${INGRESS_CLASS_NAME:?missing INGRESS_CLASS_NAME}"

GITEA_PROTOCOL="${GITEA_PROTOCOL:-https}"

SITE_NAME="${SITE_NAME:-$REPO_NAME}"
META_NAME="space-${SITE_NAME}"
META_NAMESPACE="${META_NAMESPACE:-default}"
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
npx create-docusaurus@latest "$SITE_NAME" "$TEMPLATE" --typescript --package-manager npm

cd "$SITE_NAME"

echo "Adding devcontainer..."
mkdir -p .devcontainer

if [ -f /devcontainer.json ]; then
  cp /devcontainer.json .devcontainer/devcontainer.json
  sed -i "s/\"name\": *\"[^\"]*\"/\"name\": \"${SITE_NAME}\"/" .devcontainer/devcontainer.json
else
  echo "WARNING: /devcontainer.json not found, skipping"
fi

echo "Adding Dockerfile..."
cp /docusaurus.dockerfile Dockerfile

echo "Adding GitHub Workflows..."
mkdir -p .github/workflows

cp /check.workflow.github .github/workflows/check.yaml
cp /build.workflow.github .github/workflows/build.yaml

echo "Adding Manifests..."
mkdir -p deploy/manifests

if [ -d "/kustomize" ]; then
  cp -r /kustomize/. deploy/manifests/
else
  echo "ERROR: kustomize folder not found" >&2
  exit 1
fi

echo "Updating Kubernetes manifests..."

# Replace name, app.kubernetes.io/name, and namespace in all YAML files
find deploy/manifests -name "*.yaml" -o -name "*.yml" | while read -r file; do
  sed -i "s/name: space-[^ ]*/name: ${META_NAME}/g" "$file"
  sed -i "s/app\.kubernetes\.io\/name: space-[^ ]*/app.kubernetes.io\/name: ${META_NAME}/g" "$file"
  sed -i "s/app\.kubernetes\.io\/part-of: space-[^ ]*/app.kubernetes.io\/name: ${META_NAME}/g" "$file"
  sed -i "s/namespace: [^ ]*/namespace: ${META_NAMESPACE}/g" "$file"
  sed -i "s|image: [^ ]*|image: ${REGISTRY}/${REGISTRY_ORG}/${REPO_NAME}:latest|g" "$file"
  sed -i "s/host: \${EXPOSE_URL}/host: ${EXPOSE_URL}/g" "$file"
  sed -i "s/ingressClassName: \${INGRESS_CLASS_NAME}/ingressClassName: ${INGRESS_CLASS_NAME}/g" "$file"
done

echo "Kubernetes manifests updated with META_NAME=${META_NAME}, META_NAMESPACE=${META_NAMESPACE}"

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
git remote add origin "${GITEA_PROTOCOL}://${GIT_USERNAME}:${GITEA_TOKEN}@${GITEA_HOST}/${GIT_OWNER}/${REPO_NAME}.git"
git push -u origin "$DEFAULT_BRANCH"

echo "Done."