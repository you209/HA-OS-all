#!/usr/bin/env bash
set -euo pipefail

OPTIONS=/data/options.json
LAUNCHER_DIR=/data/launcher
VENV_DIR=/data/venv
LOGS_DIR=/data/logs

mkdir -p /data "$LOGS_DIR" /addons

get_opt() {
  jq -r "$1 // empty" "$OPTIONS"
}

GITHUB_USERNAME="$(get_opt '.github_username')"
LAUNCHER_REPO="$(get_opt '.launcher_repo')"
LAUNCHER_BRANCH="$(get_opt '.launcher_branch')"
GITHUB_TOKEN="$(get_opt '.github_token')"
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

if [ -z "$GITHUB_TOKEN" ]; then
  echo "ERROR: github_token is empty. Add a fine-grained GitHub token in the add-on options."
  echo "The token only needs read access to the private repos you want this launcher to sync."
  exit 1
fi

if [ ! -f /data/secret_key ]; then
  python - <<'PY'
import secrets
from pathlib import Path
Path('/data/secret_key').write_text(secrets.token_urlsafe(48))
PY
fi
SECRET_KEY="$(cat /data/secret_key)"

AUTH_HEADER="AUTHORIZATION: bearer ${GITHUB_TOKEN}"
REPO_URL="https://github.com/${LAUNCHER_REPO}.git"

if [ -d "$LAUNCHER_DIR/.git" ]; then
  echo "Updating Launcher from ${LAUNCHER_REPO}..."
  git -C "$LAUNCHER_DIR" -c http.https://github.com/.extraheader="$AUTH_HEADER" fetch --depth=1 origin "$LAUNCHER_BRANCH"
  git -C "$LAUNCHER_DIR" checkout "$LAUNCHER_BRANCH"
  git -C "$LAUNCHER_DIR" reset --hard "origin/${LAUNCHER_BRANCH}"
else
  echo "Cloning Launcher from ${LAUNCHER_REPO}..."
  rm -rf "$LAUNCHER_DIR"
  git -c http.https://github.com/.extraheader="$AUTH_HEADER" clone --depth=1 --branch "$LAUNCHER_BRANCH" "$REPO_URL" "$LAUNCHER_DIR"
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
