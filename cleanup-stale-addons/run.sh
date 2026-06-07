#!/usr/bin/env bash
set -euo pipefail

echo "=== Cleanup Stale Add-on Wrappers ==="
echo "Checking /addons for old wrappers that still clone private GitHub repos..."

BAD_PATTERNS=(
  "github.com/you209/Find-My-Local-Pollie.git"
  "github.com/you209/Quote-Machine.git"
  "github.com/you209/ST.git"
  "github.com/you209/Family-Database.git"
  "ghcr.io/you209/quote-machine-addon"
)

CANDIDATE_DIRS=(
  "/addons/find-my-local-pollie"
  "/addons/find_my_local_pollie"
  "/addons/quote-machine"
  "/addons/quote_machine"
  "/addons/st"
  "/addons/st_security_tool"
  "/addons/family-database"
  "/addons/family_database"
  "/addons/familyroot"
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

echo "Searching wider /addons tree for any remaining old private clone Dockerfiles..."
while IFS= read -r file; do
  dir="$(dirname "$file")"
  echo "Removing stale wrapper containing bad Dockerfile: $dir"
  rm -rf "$dir"
  removed=$((removed + 1))
done < <(grep -RslE "github.com/you209/(Find-My-Local-Pollie|Quote-Machine|ST|Family-Database)\.git|ghcr\.io/you209/quote-machine-addon" /addons 2>/dev/null || true)

echo "Removed $removed stale wrapper folder(s)."
echo "Now restart GitHub Project Launcher, run Sync, then run: ha addons reload"
echo "=== Cleanup complete ==="
