#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_NAME="Android Release APK"
RELEASE_REF="main"
BUMP_KIND="patch"
VERSION_NAME=""
VERSION_CODE=""
TAG_NAME=""
RELEASE_NAME=""
COMMIT_MESSAGE=""
YES=0
DRY_RUN=0
WATCH_RUN=1
LOCAL_BUILD=1
VERIFY_DOWNLOAD=1
ALLOW_DIRTY=0

usage() {
  cat <<'EOF'
Usage:
  scripts/release-android-apk.sh [options]

Default behavior:
  - Requires a clean local main branch synced with origin/main.
  - Bumps flutter_client/pubspec.yaml from X.Y.Z+N to X.Y.(Z+1)+(N+1).
  - Commits and pushes the version bump.
  - Triggers the GitHub Actions workflow "Android Release APK".
  - Watches the workflow and verifies the published manifest/APK SHA256.

Options:
  --yes, -y                 Skip confirmation prompt.
  --dry-run                 Print the planned release without changing files.
  --bump patch|minor|major  Version bump kind. Default: patch.
  --version X.Y.Z           Set versionName explicitly instead of auto bumping.
  --version-code N          Set versionCode explicitly instead of +1.
  --tag TAG                 Set release tag. Default: android-vX.Y.Z-YYYYMMDD.
  --release-name NAME       Set release title. Default: Love Chat Android X.Y.Z.
  --message MSG, -m MSG     Set version bump commit message.
  --ref BRANCH              Git ref for release workflow. Default: main.
  --skip-local-build        Skip local flutter debug APK preflight.
  --no-watch                Trigger workflow but do not wait for completion.
  --no-verify              Skip final APK download SHA256 verification.
  --allow-dirty            Allow unrelated dirty worktree files. Use with care.
  --help, -h                Show this help.

Examples:
  scripts/release-android-apk.sh --yes
  scripts/release-android-apk.sh --bump minor --yes
  scripts/release-android-apk.sh --version 1.0.6 --version-code 7 --yes
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

run() {
  info "+ $*"
  if [ "$DRY_RUN" -eq 0 ]; then
    "$@"
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes|-y)
      YES=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --bump)
      [ "$#" -ge 2 ] || die "--bump requires a value"
      BUMP_KIND="$2"
      shift 2
      ;;
    --version)
      [ "$#" -ge 2 ] || die "--version requires a value"
      VERSION_NAME="$2"
      shift 2
      ;;
    --version-code)
      [ "$#" -ge 2 ] || die "--version-code requires a value"
      VERSION_CODE="$2"
      shift 2
      ;;
    --tag)
      [ "$#" -ge 2 ] || die "--tag requires a value"
      TAG_NAME="$2"
      shift 2
      ;;
    --release-name)
      [ "$#" -ge 2 ] || die "--release-name requires a value"
      RELEASE_NAME="$2"
      shift 2
      ;;
    --message|-m)
      [ "$#" -ge 2 ] || die "--message requires a value"
      COMMIT_MESSAGE="$2"
      shift 2
      ;;
    --ref)
      [ "$#" -ge 2 ] || die "--ref requires a value"
      RELEASE_REF="$2"
      shift 2
      ;;
    --skip-local-build)
      LOCAL_BUILD=0
      shift
      ;;
    --no-watch)
      WATCH_RUN=0
      shift
      ;;
    --no-verify)
      VERIFY_DOWNLOAD=0
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC="$ROOT_DIR/flutter_client/pubspec.yaml"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/android-release-apk.yml"

cd "$ROOT_DIR"

require_command git
require_command gh
require_command awk
require_command perl
require_command curl
require_command shasum

[ -f "$PUBSPEC" ] || die "Missing $PUBSPEC"
[ -f "$WORKFLOW_FILE" ] || die "Missing $WORKFLOW_FILE"

if [ "$LOCAL_BUILD" -eq 1 ]; then
  require_command flutter
fi

if ! gh auth status >/dev/null 2>&1; then
  die "GitHub CLI is not authenticated. Run: gh auth login"
fi

REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
if [ -z "$REPO" ]; then
  remote_url="$(git config --get remote.origin.url || true)"
  case "$remote_url" in
    https://github.com/*/*.git)
      REPO="${remote_url#https://github.com/}"
      REPO="${REPO%.git}"
      ;;
    git@github.com:*.git)
      REPO="${remote_url#git@github.com:}"
      REPO="${REPO%.git}"
      ;;
    *)
      die "Cannot determine GitHub repo from origin remote"
      ;;
  esac
fi

if ! gh workflow view "$WORKFLOW_NAME" --repo "$REPO" >/dev/null 2>&1; then
  die "GitHub workflow not found: $WORKFLOW_NAME"
fi

current_version="$(awk '/^version:/{print $2; exit}' "$PUBSPEC")"
if ! [[ "$current_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
  die "Invalid Flutter version in $PUBSPEC: $current_version"
fi

current_major="${BASH_REMATCH[1]}"
current_minor="${BASH_REMATCH[2]}"
current_patch="${BASH_REMATCH[3]}"
current_code="${BASH_REMATCH[4]}"

if [ -z "$VERSION_NAME" ]; then
  case "$BUMP_KIND" in
    patch)
      next_major="$current_major"
      next_minor="$current_minor"
      next_patch=$((current_patch + 1))
      ;;
    minor)
      next_major="$current_major"
      next_minor=$((current_minor + 1))
      next_patch=0
      ;;
    major)
      next_major=$((current_major + 1))
      next_minor=0
      next_patch=0
      ;;
    *)
      die "--bump must be patch, minor, or major"
      ;;
  esac
  VERSION_NAME="${next_major}.${next_minor}.${next_patch}"
fi

if ! [[ "$VERSION_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  die "--version must use X.Y.Z format"
fi

if [ -z "$VERSION_CODE" ]; then
  VERSION_CODE=$((current_code + 1))
elif ! [[ "$VERSION_CODE" =~ ^[0-9]+$ ]]; then
  die "--version-code must be an integer"
fi

if [ "$VERSION_CODE" -le "$current_code" ]; then
  die "versionCode must increase. Current: $current_code, requested: $VERSION_CODE"
fi

new_version="${VERSION_NAME}+${VERSION_CODE}"

tag_exists() {
  gh release view "$1" --repo "$REPO" >/dev/null 2>&1 ||
    git ls-remote --exit-code --tags origin "refs/tags/$1" >/dev/null 2>&1
}

if [ -z "$TAG_NAME" ]; then
  base_tag="android-v${VERSION_NAME}-$(date +%Y%m%d)"
  TAG_NAME="$base_tag"
  if tag_exists "$TAG_NAME"; then
    tag_suffix="$(date +%H%M)"
    candidate="${base_tag}-${tag_suffix}"
    counter=2
    while tag_exists "$candidate"; do
      candidate="${base_tag}-${tag_suffix}-${counter}"
      counter=$((counter + 1))
    done
    TAG_NAME="$candidate"
  fi
fi

if [ -z "$RELEASE_NAME" ]; then
  RELEASE_NAME="Love Chat Android ${VERSION_NAME}"
fi

if [ -z "$COMMIT_MESSAGE" ]; then
  COMMIT_MESSAGE="chore: Bump Android version to ${VERSION_NAME}"
fi

branch="$(git branch --show-current)"
if [ "$branch" != "$RELEASE_REF" ]; then
  die "Current branch is '$branch'. Switch to '$RELEASE_REF' before releasing."
fi

if [ "$ALLOW_DIRTY" -eq 0 ]; then
  if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    die "Working tree is not clean. Commit/stash unrelated changes first, or use --allow-dirty intentionally."
  fi
fi

if [ "$DRY_RUN" -eq 0 ]; then
  git fetch origin "$RELEASE_REF"
  git pull --ff-only origin "$RELEASE_REF"
fi

if [ "$ALLOW_DIRTY" -eq 0 ]; then
  if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    die "Working tree became dirty after syncing from origin."
  fi
fi

cat <<EOF
Android APK release plan
  Repo:         $REPO
  Ref:          $RELEASE_REF
  Workflow:     $WORKFLOW_NAME
  Version:      $current_version -> $new_version
  Tag:          $TAG_NAME
  Release name: $RELEASE_NAME
  Commit:       $COMMIT_MESSAGE
  Local build:  $([ "$LOCAL_BUILD" -eq 1 ] && printf yes || printf no)
  Watch run:    $([ "$WATCH_RUN" -eq 1 ] && printf yes || printf no)
  Verify APK:   $([ "$VERIFY_DOWNLOAD" -eq 1 ] && printf yes || printf no)
EOF

if [ "$DRY_RUN" -eq 1 ]; then
  info "Dry run complete. No files were changed."
  exit 0
fi

if [ "$YES" -eq 0 ]; then
  printf 'Continue with release? [y/N] '
  read -r answer
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      die "Release cancelled"
      ;;
  esac
fi

CURRENT_VERSION="$current_version" NEW_VERSION="$new_version" \
  perl -0pi -e 's/^version:\s*\Q$ENV{CURRENT_VERSION}\E\s*$/version: $ENV{NEW_VERSION}/m' "$PUBSPEC"

updated_version="$(awk '/^version:/{print $2; exit}' "$PUBSPEC")"
[ "$updated_version" = "$new_version" ] || die "Failed to update $PUBSPEC"

if [ "$LOCAL_BUILD" -eq 1 ]; then
  info "Running local debug APK preflight..."
  (cd "$ROOT_DIR/flutter_client" && flutter build apk --debug)
fi

git diff --check
git add "$PUBSPEC"
git commit -m "$COMMIT_MESSAGE"
git push origin "$RELEASE_REF"

head_sha="$(git rev-parse HEAD)"

info "Triggering GitHub Actions release workflow..."
gh workflow run "$WORKFLOW_NAME" \
  --repo "$REPO" \
  --ref "$RELEASE_REF" \
  -f "tag_name=$TAG_NAME" \
  -f "release_name=$RELEASE_NAME"

run_id=""
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  run_id="$(gh run list \
    --repo "$REPO" \
    --workflow "$WORKFLOW_NAME" \
    --branch "$RELEASE_REF" \
    --limit 20 \
    --json databaseId,event,headSha \
    --jq ".[] | select(.event == \"workflow_dispatch\" and .headSha == \"$head_sha\") | .databaseId" | head -n 1)"
  if [ -n "$run_id" ]; then
    break
  fi
  sleep 5
done

if [ -z "$run_id" ]; then
  info "Workflow triggered, but run ID was not found yet."
  info "Check runs with: gh run list --workflow \"$WORKFLOW_NAME\" --branch $RELEASE_REF --limit 5"
  exit 0
fi

run_url="https://github.com/${REPO}/actions/runs/${run_id}"
info "Workflow run: $run_url"

if [ "$WATCH_RUN" -eq 0 ]; then
  info "Not watching workflow. To watch later:"
  info "  gh run watch $run_id --repo $REPO --exit-status --interval 15"
  exit 0
fi

gh run watch "$run_id" --repo "$REPO" --exit-status --interval 15

release_url="https://github.com/${REPO}/releases/tag/${TAG_NAME}"
manifest_url="https://github.com/${REPO}/releases/download/${TAG_NAME}/android-version.json"
latest_manifest_url="https://github.com/${REPO}/releases/latest/download/android-version.json"
apk_url="https://github.com/${REPO}/releases/download/${TAG_NAME}/LoveChat-Android.apk"

info "Release published: $release_url"
info "Manifest:"
manifest="$(curl -fsSL "$manifest_url")"
printf '%s\n' "$manifest"

manifest_version="$(printf '%s\n' "$manifest" | sed -n 's/.*"versionName": "\([^"]*\)".*/\1/p')"
manifest_code="$(printf '%s\n' "$manifest" | sed -n 's/.*"versionCode": \([0-9][0-9]*\).*/\1/p')"
manifest_sha="$(printf '%s\n' "$manifest" | sed -n 's/.*"sha256": "\([^"]*\)".*/\1/p')"

[ "$manifest_version" = "$VERSION_NAME" ] || die "Manifest versionName mismatch: $manifest_version"
[ "$manifest_code" = "$VERSION_CODE" ] || die "Manifest versionCode mismatch: $manifest_code"
[ -n "$manifest_sha" ] || die "Manifest is missing sha256"

info "Latest manifest URL: $latest_manifest_url"
curl -fsSL "$latest_manifest_url" >/dev/null

if [ "$VERIFY_DOWNLOAD" -eq 1 ]; then
  info "Verifying published APK SHA256. This downloads the APK once..."
  downloaded_sha="$(curl -fsSL "$apk_url" | shasum -a 256 | awk '{print $1}')"
  [ "$downloaded_sha" = "$manifest_sha" ] || die "APK SHA256 mismatch: $downloaded_sha != $manifest_sha"
  info "APK SHA256 verified: $downloaded_sha"
fi

info "Done."
