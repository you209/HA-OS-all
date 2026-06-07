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

repair_local_addon_wrappers() {
  python - <<'PY'
from pathlib import Path
import textwrap

BASE = Path("/addons")

def write(path: Path, content: str, executable: bool = False):
    path.write_text(textwrap.dedent(content).lstrip())
    if executable:
        path.chmod(0o755)

def clean(d: Path):
    for name in ("build.yaml", "build.yml"):
        p = d / name
        if p.exists():
            p.unlink()

def addon_exists(folder: str) -> bool:
    return (BASE / folder / "source").is_dir()

def node_docker(port: int, build_cmd: str = "", extra_before_build: str = "") -> str:
    extra = extra_before_build.strip()
    build = build_cmd.strip()
    return f"""
    FROM node:20-bookworm-slim

    WORKDIR /app

    COPY source/package*.json ./
    RUN npm ci --omit=dev || npm install --omit=dev

    COPY source/ ./
    {extra}
    {build}

    COPY run.sh /run.sh
    RUN chmod a+x /run.sh

    EXPOSE {port}
    CMD ["/run.sh"]
    """

def write_quote(folder="quote_machine"):
    d = BASE / folder
    if not addon_exists(folder):
        return
    clean(d)
    write(d / "config.yaml", """
    name: Quote Machine
    version: "1.0.0"
    slug: quote_machine
    description: Gallagher Security Quoting Tool
    arch:
      - amd64
    startup: application
    boot: manual
    init: false
    webui: "http://[HOST]:[PORT:3000]"
    ports:
      3000/tcp: 3000
    ports_description:
      3000/tcp: Web interface
    map:
      - type: data
        read_only: false
    options: {}
    schema: {}
    """)
    write(d / "Dockerfile", node_docker(3000))
    write(d / "run.sh", """
    #!/usr/bin/env bash
    set -e

    mkdir -p /data/quote-machine
    export NODE_ENV=production
    export PORT=3000

    cd /app
    exec npm start
    """, True)
    write(d / "README.md", "# Quote Machine\n\nLocal Home Assistant add-on generated by GitHub Project Launcher.\n")

def write_pollie(folder="find_my_local_pollie"):
    d = BASE / folder
    if not addon_exists(folder):
        return
    clean(d)
    write(d / "config.yaml", """
    name: Find My Local Pollie
    version: "0.1.0"
    slug: find_my_local_pollie
    description: Find local political representatives from Home Assistant
    arch:
      - amd64
    startup: application
    boot: manual
    init: false
    webui: "http://[HOST]:[PORT:3000]"
    ports:
      3000/tcp: 3001
    ports_description:
      3000/tcp: Web interface
    map:
      - type: data
        read_only: false
    options: {}
    schema: {}
    """)
    write(d / "Dockerfile", node_docker(3000, build_cmd="RUN npm run build", extra_before_build="RUN npx prisma generate || true"))
    write(d / "run.sh", """
    #!/usr/bin/env bash
    set -e

    mkdir -p /data/find-my-local-pollie
    export NODE_ENV=production
    export PORT=3000

    cd /app
    exec npm start
    """, True)
    write(d / "README.md", "# Find My Local Pollie\n\nLocal Home Assistant add-on generated by GitHub Project Launcher.\n")

def write_st(folder="st_security_tool"):
    d = BASE / folder
    if not addon_exists(folder):
        return
    clean(d)
    write(d / "config.yaml", """
    name: ST Security Tool
    version: "0.1.0"
    slug: st_security_tool
    description: Security tooling platform for Tecom, Hikvision, Gallagher and site-based security work
    arch:
      - amd64
    startup: application
    boot: manual
    init: false
    webui: "http://[HOST]:[PORT:8000]"
    ports:
      8000/tcp: 8000
    ports_description:
      8000/tcp: Web/API interface
    map:
      - type: data
        read_only: false
    options: {}
    schema: {}
    """)
    write(d / "Dockerfile", """
    FROM python:3.11-slim

    WORKDIR /app

    RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender1 \
        && rm -rf /var/lib/apt/lists/*

    COPY source/ /app/

    RUN pip install --no-cache-dir -r /app/backend/requirements.txt

    COPY run.sh /run.sh
    RUN chmod a+x /run.sh

    EXPOSE 8000
    CMD ["/run.sh"]
    """)
    write(d / "run.sh", """
    #!/usr/bin/env bash
    set -e

    mkdir -p /data/st

    export ST_DATA_DIR=/data/st
    export PYTHONPATH=/app/backend

    cd /app/backend
    exec uvicorn app.main:app --host 0.0.0.0 --port 8000
    """, True)
    write(d / "README.md", "# ST Security Tool\n\nLocal Home Assistant add-on generated by GitHub Project Launcher.\n")

def write_family(folder: str, slug: str):
    d = BASE / folder
    if not addon_exists(folder):
        return
    clean(d)
    write(d / "config.yaml", f"""
    name: FamilyRoot
    version: "0.1.0"
    slug: {slug}
    description: Local-first family history database with photos, family tree, timeline and map.
    arch:
      - amd64
    startup: application
    boot: manual
    init: false
    webui: "http://[HOST]:[PORT:5050]"
    ports:
      5050/tcp: 5050
    ports_description:
      5050/tcp: Web interface
    map:
      - type: data
        read_only: false
    options: {{}}
    schema: {{}}
    watchdog: "http://[HOST]:[PORT:5050]/api/health"
    """)
    write(d / "Dockerfile", """
    FROM python:3.11-slim

    WORKDIR /app

    RUN apt-get update && apt-get install -y --no-install-recommends \
        libatlas-base-dev \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender-dev \
        tesseract-ocr \
        ffmpeg \
        curl \
        ca-certificates \
        && rm -rf /var/lib/apt/lists/*

    RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
        apt-get install -y nodejs && \
        rm -rf /var/lib/apt/lists/*

    COPY source/ /app/

    RUN pip install --no-cache-dir -r /app/backend/requirements.txt
    RUN cd /app/frontend && npm install && npm run build

    COPY run.sh /run.sh
    RUN chmod a+x /run.sh

    EXPOSE 5050
    CMD ["/run.sh"]
    """)
    write(d / "run.sh", """
    #!/usr/bin/env bash
    set -e

    mkdir -p /data/familyroot/data
    mkdir -p /data/familyroot/media

    rm -rf /app/data
    ln -s /data/familyroot/data /app/data

    rm -rf /app/media
    ln -s /data/familyroot/media /app/media

    cd /app/backend
    exec python app.py
    """, True)
    write(d / "README.md", "# FamilyRoot\n\nLocal Home Assistant add-on generated by GitHub Project Launcher.\n")

write_quote("quote_machine")
write_st("st_security_tool")
write_pollie("find_my_local_pollie")
write_family("familyroot", "familyroot")
write_family("family_database", "family_database")

print("Local add-on wrappers repaired where source/ folders exist.")
PY
}

repair_local_addon_wrappers || true

(
  while true; do
    sleep 60
    repair_local_addon_wrappers || true
  done
) &

cd "$LAUNCHER_DIR"
echo "Starting GitHub Project Launcher on port 8000..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
