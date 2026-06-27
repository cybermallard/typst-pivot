#!/usr/bin/env bash
# Catches any pivot pin that DISAGREES with typst.toml
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
manifest="$root/typst.toml"

version="$(grep -E '^version[[:space:]]*=' "$manifest" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
if [ -z "${version:-}" ]; then
  echo "error: could not read version from $manifest" >&2
  exit 2
fi
echo "manifest version: $version"

fail=0
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  file="${hit%%:*}"
  pinned="${hit##*pivot:}"
  [ -z "$pinned" ] && continue
  if [ "$pinned" != "$version" ]; then
    echo "MISMATCH: $file pins pivot:$pinned (expected $version)"
    fail=1
  fi
done <<EOF
$(grep -rnoE '(@preview|@local)/pivot:[0-9]+\.[0-9]+\.[0-9]+' "$root" \
    --include='*.md' --include='*.typ' --include='*.yml' --include='*.yaml' \
    --exclude-dir='.git' 2>/dev/null || true)
EOF

if [ "$fail" -ne 0 ]; then
  echo "Version pins are out of sync with typst.toml ($version)." >&2
  echo "Update the pins, or the manifest, so they agree." >&2
  exit 1
fi
echo "OK: all pivot version pins match $version."
