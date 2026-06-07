#!/usr/bin/env bash
set -euo pipefail

BASE=/addons

echo "=== Cleanup + Force Repair Add-on Wrappers v1.4.2 ==="
echo "Using BASE=$BASE"

BAD_PATTERNS=(
  "github.com/you209/Find-My-Local-Pollie.git"
  "github.com/you209/Quote-Machine.git"
  "github.com/you209/ST.git"
  "github.com/you209/Family-Database.git"
  "ghcr.io/you209/quote-machine-addon"
)

CANDIDATE_DIRS=(
  "$BASE/find-my-local-pollie"
  "$BASE/quote-machine"
  "$BASE/st"
  "$BASE/family-database"
  "$BASE/familyroot"
)

removed=0

remove_if_bad() {
  local dir="$1"
  [ -d "$dir" ] || return 0

  local bad=0
  for pattern in "${BAD_PATTERNS[@]}"; do
    if grep -Rqs "$pattern" "$dir" 2>/dev/null; then
      bad=1
      break
    fi
  done

  if [ "$bad" = "1" ]; then
    echo "Removing stale bad wrapper: $dir"
    rm -rf "$dir"
    removed=$((removed + 1))
  else
    echo "Keeping $dir - no old private clone/GHCR wrapper found."
  fi
}

for dir in "${CANDIDATE_DIRS[@]}"; do
  remove_if_bad "$dir"
done

while IFS= read -r file; do
  dir="$(dirname "$file")"
  case "$dir" in
    "$BASE/find_my_local_pollie"|"$BASE/quote_machine"|"$BASE/st_security_tool"|"$BASE/family_database")
      echo "Overwriting managed wrapper instead of deleting: $dir"
      ;;
    *)
      echo "Removing stale wrapper containing bad Dockerfile: $dir"
      rm -rf "$dir"
      removed=$((removed + 1))
      ;;
  esac
done < <(grep -RslE "github.com/you209/(Find-My-Local-Pollie|Quote-Machine|ST|Family-Database)\.git|ghcr\.io/you209/quote-machine-addon" "$BASE" 2>/dev/null || true)

write_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
}

note_source() {
  local dir="$1"
  local name="$2"
  if [ -d "$dir/source/.git" ]; then
    echo "$name source exists: $dir/source"
  elif [ -d "$dir/source" ]; then
    echo "$name source folder exists but is not a git checkout: $dir/source"
  else
    echo "WARNING: $name source is missing at $dir/source. Run GitHub Project Launcher sync after this repair."
  fi
}

repair_node_addon() {
  local folder="$1"
  local name="$2"
  local slug="$3"
  local desc="$4"
  local host_port="$5"
  local data_dir="$6"
  local dir="$BASE/$folder"

  mkdir -p "$dir"
  rm -f "$dir/build.yaml" "$dir/build.yml" "$dir/config.yml"

  write_file "$dir/config.yaml" <<EOF
name: $name
version: "0.1.0"
slug: $slug
description: $desc
arch:
  - amd64
startup: application
boot: manual
init: false
webui: "http://[HOST]:[PORT:3000]"
ports:
  3000/tcp: $host_port
ports_description:
  3000/tcp: Web interface
map:
  - type: data
    read_only: false
options: {}
schema: {}
EOF

  write_file "$dir/Dockerfile" <<'EOF'
FROM node:20-bookworm-slim
WORKDIR /app
COPY source/package*.json ./
RUN npm ci || npm install
COPY source/ ./
RUN npm run build || true
COPY run.sh /run.sh
RUN chmod a+x /run.sh
EXPOSE 3000
CMD ["/run.sh"]
EOF

  write_file "$dir/run.sh" <<EOF
#!/usr/bin/env bash
set -e
mkdir -p $data_dir
export NODE_ENV=production
export PORT=3000
cd /app
exec npm start
EOF
  chmod +x "$dir/run.sh"

  write_file "$dir/README.md" <<EOF
# $name

Local Home Assistant add-on wrapper generated/repaired by Cleanup Stale Add-on Wrappers.
Source must be cloned by GitHub Project Launcher into \`source/\`.
EOF

  echo "Repaired wrapper: $dir"
  note_source "$dir" "$name"
}

repair_pollie_addon() {
  local dir="$BASE/find_my_local_pollie"
  mkdir -p "$dir"
  rm -f "$dir/build.yaml" "$dir/build.yml" "$dir/config.yml"

  write_file "$dir/config.yaml" <<'EOF'
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
EOF

  write_file "$dir/Dockerfile" <<'EOF'
FROM node:20-bookworm-slim
WORKDIR /app
COPY source/package*.json ./
RUN npm ci || npm install
RUN npm install -g serve@14.2.4
COPY source/ ./
RUN npx prisma generate || true
RUN npm run build
COPY run.sh /run.sh
RUN chmod a+x /run.sh
EXPOSE 3000
CMD ["/run.sh"]
EOF

  write_file "$dir/run.sh" <<'EOF'
#!/usr/bin/env bash
set -e
mkdir -p /data/find_my_local_pollie
export NODE_ENV=production
export PORT=3000
cd /app
if [ ! -d /app/out ]; then
  echo "ERROR: /app/out does not exist. The Next.js static export build did not produce an out folder."
  exit 1
fi
exec serve -s /app/out -l tcp://0.0.0.0:3000
EOF
  chmod +x "$dir/run.sh"

  write_file "$dir/README.md" <<'EOF'
# Find My Local Pollie

Local Home Assistant add-on wrapper generated/repaired by Cleanup Stale Add-on Wrappers.
This app uses Next.js `output: export`, so it is served from the generated `out/` folder with `serve` instead of `next start`.
Source must be cloned by GitHub Project Launcher into `source/`.
EOF

  echo "Repaired wrapper: $dir"
  note_source "$dir" "Find My Local Pollie"
}

repair_st_addon() {
  local dir="$BASE/st_security_tool"
  mkdir -p "$dir"
  rm -f "$dir/build.yaml" "$dir/build.yml" "$dir/config.yml"

  write_file "$dir/config.yaml" <<'EOF'
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
EOF

  write_file "$dir/Dockerfile" <<'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*
COPY source/ /app/
RUN if [ -f /app/backend/requirements.txt ]; then pip install --no-cache-dir -r /app/backend/requirements.txt; elif [ -f /app/requirements.txt ]; then pip install --no-cache-dir -r /app/requirements.txt; fi
COPY run.sh /run.sh
RUN chmod a+x /run.sh
EXPOSE 8000
CMD ["/run.sh"]
EOF

  write_file "$dir/run.sh" <<'EOF'
#!/usr/bin/env bash
set -e
mkdir -p /data/st_security_tool
export PYTHONPATH=/app/backend:/app
cd /app/backend
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
EOF
  chmod +x "$dir/run.sh"

  write_file "$dir/README.md" <<'EOF'
# ST Security Tool

Local Home Assistant add-on wrapper generated/repaired by Cleanup Stale Add-on Wrappers.
Source must be cloned by GitHub Project Launcher into `source/`.
EOF
  echo "Repaired wrapper: $dir"
  note_source "$dir" "ST Security Tool"
}

repair_family_addon() {
  local dir="$BASE/family_database"
  mkdir -p "$dir"
  rm -f "$dir/build.yaml" "$dir/build.yml" "$dir/config.yml"

  write_file "$dir/config.yaml" <<'EOF'
name: FamilyRoot
version: "0.1.0"
slug: family_database
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
options: {}
schema: {}
watchdog: "http://[HOST]:[PORT:5050]/api/health"
EOF

  write_file "$dir/Dockerfile" <<'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libopenblas-dev libglib2.0-0 libsm6 libxext6 libxrender-dev \
    tesseract-ocr ffmpeg curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*
COPY source/ /app/
RUN pip install --no-cache-dir -r /app/backend/requirements.txt
RUN if [ -f /app/frontend/package.json ]; then cd /app/frontend && npm install && npm run build; fi
COPY run.sh /run.sh
RUN chmod a+x /run.sh
EXPOSE 5050
CMD ["/run.sh"]
EOF

  write_file "$dir/run.sh" <<'EOF'
#!/usr/bin/env bash
set -e
mkdir -p /data/family_database/data /data/family_database/media
rm -rf /app/data
ln -s /data/family_database/data /app/data
rm -rf /app/media
ln -s /data/family_database/media /app/media
cd /app/backend
exec python app.py
EOF
  chmod +x "$dir/run.sh"

  write_file "$dir/README.md" <<'EOF'
# FamilyRoot

Local Home Assistant add-on wrapper generated/repaired by Cleanup Stale Add-on Wrappers.
Source must be cloned by GitHub Project Launcher into `source/`.

Debian Trixie note: this wrapper uses `libopenblas-dev` instead of the removed `libatlas-base-dev` package.
EOF
  echo "Repaired wrapper: $dir"
  note_source "$dir" "FamilyRoot"
}

repair_pollie_addon
repair_node_addon "quote_machine" "Quote Machine" "quote_machine" "Gallagher Security Quoting Tool" "3000" "/data/quote_machine"
repair_st_addon
repair_family_addon

echo "Removed $removed stale wrapper folder(s)."
echo "Now run: ha addons reload"
echo "=== Cleanup + force repair complete ==="
