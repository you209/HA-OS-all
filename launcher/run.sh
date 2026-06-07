#!/usr/bin/env bash
set -euo pipefail

OPTIONS=/data/options.json
LAUNCHER_DIR=/data/launcher
VENV_DIR=/data/venv
LOGS_DIR=/data/logs
ASKPASS=/tmp/github-askpass.sh
APP_REPOS_JSON=/data/app_repositories.json

mkdir -p /data "$LOGS_DIR" /addons

get_opt() {
  jq -r "$1 // empty" "$OPTIONS"
}

GITHUB_USERNAME="$(get_opt '.github_username')"
LAUNCHER_REPO="$(get_opt '.launcher_repo')"
LAUNCHER_BRANCH="$(get_opt '.launcher_branch')"
GITHUB_TOKEN="$(get_opt '.launcher_token')"
LEGACY_GITHUB_TOKEN="$(get_opt '.github_token')"
ADMIN_USERNAME="$(get_opt '.admin_username')"
ADMIN_PASSWORD="$(get_opt '.admin_password')"
AUTO_PULL="$(get_opt '.auto_pull')"
SYNC_INTERVAL="$(get_opt '.sync_interval_minutes')"

: "${GITHUB_USERNAME:=you209}"
: "${LAUNCHER_REPO:=you209/Launcher}"
: "${LAUNCHER_BRANCH:=main}"
: "${ADMIN_USERNAME:=admin}"
: "${ADMIN_PASSWORD:=change-this-now}"
: "${AUTO_PULL:=true}"
: "${SYNC_INTERVAL:=15}"

# Backward compatibility for the older config field.
if [ -z "$GITHUB_TOKEN" ] && [ -n "$LEGACY_GITHUB_TOKEN" ]; then
  GITHUB_TOKEN="$LEGACY_GITHUB_TOKEN"
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "ERROR: launcher_token is empty. Add a fine-grained GitHub token that can read ${LAUNCHER_REPO}."
  echo "Use one fine-grained token per app under app_repositories. Each app token only needs Contents: read-only for that one repo."
  exit 1
fi

# Store the per-app repo token list on the HA box only. This file is not committed to GitHub.
jq -c '.app_repositories // []' "$OPTIONS" > "$APP_REPOS_JSON"
chmod 600 "$APP_REPOS_JSON"

if [ ! -f /data/secret_key ]; then
  python - <<'PY'
import secrets
from pathlib import Path
Path('/data/secret_key').write_text(secrets.token_urlsafe(48))
PY
fi
SECRET_KEY="$(cat /data/secret_key)"

cat > "$ASKPASS" <<'EOF'
#!/usr/bin/env sh
case "$1" in
  *Username*) echo "x-access-token" ;;
  *Password*) echo "$GITHUB_TOKEN" ;;
  *) echo "" ;;
esac
EOF
chmod 700 "$ASKPASS"

export GIT_ASKPASS="$ASKPASS"
export GIT_TERMINAL_PROMPT=0
export GITHUB_TOKEN

REPO_URL="https://github.com/${LAUNCHER_REPO}.git"

if [ -d "$LAUNCHER_DIR/.git" ]; then
  echo "Updating Launcher from ${LAUNCHER_REPO}..."
  git -C "$LAUNCHER_DIR" remote set-url origin "$REPO_URL"
  git -C "$LAUNCHER_DIR" fetch --depth=1 origin "$LAUNCHER_BRANCH"
  git -C "$LAUNCHER_DIR" checkout "$LAUNCHER_BRANCH"
  git -C "$LAUNCHER_DIR" reset --hard "origin/${LAUNCHER_BRANCH}"
else
  echo "Cloning Launcher from ${LAUNCHER_REPO}..."
  rm -rf "$LAUNCHER_DIR"
  git clone --depth=1 --branch "$LAUNCHER_BRANCH" "$REPO_URL" "$LAUNCHER_DIR"
  git -C "$LAUNCHER_DIR" remote set-url origin "$REPO_URL"
fi

if [ ! -d "$VENV_DIR" ]; then
  python -m venv "$VENV_DIR"
fi

. "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip wheel setuptools
python -m pip install -r "$LAUNCHER_DIR/requirements.txt"

cat > "$LAUNCHER_DIR/.env" <<EOF
APP_NAME=GitHub Project Launcher
HOST=0.0.0.0
PORT=8000
SECRET_KEY=${SECRET_KEY}
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
GITHUB_USERNAME=${GITHUB_USERNAME}
GITHUB_TOKEN=${GITHUB_TOKEN}
APP_REPOSITORIES_JSON=${APP_REPOS_JSON}
APPS_DIR=/addons
LOGS_DIR=${LOGS_DIR}
DATA_DIR=/data
DB_PATH=/data/launcher.db
SYNC_INTERVAL_MINUTES=${SYNC_INTERVAL}
AUTO_PULL=${AUTO_PULL}
AUTO_ADD_NEW_REPOS=true
EOF

cd "$LAUNCHER_DIR"
echo "Starting GitHub Project Launcher on port 8000..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
