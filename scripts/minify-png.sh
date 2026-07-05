#!/usr/bin/env bash
#
# minify-png — shrink PNGs locally, the way TinyPNG does.
#
# Two stages, each used only if its tool is installed:
#   1. pngquant — lossy palette quantization. This is the large saving and what
#      TinyPNG is really doing. For flat diagram PNGs it is visually lossless
#      while cutting size by more than half.
#   2. oxipng   — lossless recompression and metadata strip, run over stage 1's
#      output.
#
# A file is overwritten only when the result is genuinely smaller, so the tool
# is safe to re-run and safe to point at a whole directory.
#
# Install the tools once:  brew install pngquant oxipng

set -euo pipefail

quality="65-90"
recurse=0
keep=0
dry=0

print_help() {
  echo "minify-png — shrink PNGs locally, the way TinyPNG does."
  echo
  echo "Pipeline: pngquant (lossy palette quantization) then oxipng (lossless)."
  echo "A file is overwritten only when the result is smaller, so re-running is safe."
  echo
  echo "Install the tools once:  brew install pngquant oxipng"
  echo
  echo "Usage: minify-png [options] [path ...]"
  echo "  path      PNG files or directories (default: current directory)"
  echo "  -q RANGE  pngquant quality range low-high 0-100 (default 65-90)"
  echo "  -r        recurse into directories"
  echo "  -k        keep originals; write <name>.min.png beside each"
  echo "  -n        dry run — report savings without writing"
  echo "  -h        show this help"
}

# Human-readable byte count.
human() {
  awk -v b="$1" 'BEGIN { if (b < 1024) printf "%d B", b; else printf "%.1f KB", b / 1024 }'
}

have() { command -v "$1" >/dev/null 2>&1; }

# ---- parse arguments -------------------------------------------------------
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    -q | --quality)
      if [ $# -lt 2 ]; then echo "minify-png: -q needs a value" >&2; exit 2; fi
      quality="$2"; shift 2 ;;
    -r | --recurse) recurse=1; shift ;;
    -k | --keep) keep=1; shift ;;
    -n | --dry-run) dry=1; shift ;;
    -h | --help) print_help; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do paths+=("$1"); shift; done ;;
    -*) echo "minify-png: unknown option: $1" >&2; exit 2 ;;
    *) paths+=("$1"); shift ;;
  esac
done
if [ ${#paths[@]} -eq 0 ]; then paths=("."); fi

# Fail fast on a malformed -q. pngquant would reject it at every file, and the
# blanket copy-fallback below would silently skip the lossy stage all run long.
if [[ "$quality" =~ ^([0-9]{1,3})-([0-9]{1,3})$ ]]; then
  if [ "${BASH_REMATCH[1]}" -gt "${BASH_REMATCH[2]}" ] \
    || [ "${BASH_REMATCH[2]}" -gt 100 ]; then
    echo "minify-png: -q wants low-high with low <= high <= 100, got: $quality" >&2
    exit 2
  fi
else
  echo "minify-png: -q wants a range like 65-90, got: $quality" >&2
  exit 2
fi

# ---- check tools -----------------------------------------------------------
have_pngquant=0
have_oxipng=0
if have pngquant; then have_pngquant=1; fi
if have oxipng; then have_oxipng=1; fi

if [ $have_pngquant -eq 0 ] && [ $have_oxipng -eq 0 ]; then
  echo "minify-png: needs pngquant and/or oxipng — neither is installed." >&2
  echo "  brew install pngquant oxipng" >&2
  exit 1
fi
if [ $have_pngquant -eq 0 ]; then
  echo "minify-png: pngquant not found — skipping the lossy step (the big win)." >&2
  echo "            install it with: brew install pngquant" >&2
fi
if [ $have_oxipng -eq 0 ]; then
  echo "minify-png: oxipng not found — skipping the lossless polish." >&2
  echo "            install it with: brew install oxipng" >&2
fi

# ---- gather PNG files ------------------------------------------------------
files=()
for p in "${paths[@]}"; do
  if [ -f "$p" ]; then
    files+=("$p")
  elif [ -d "$p" ]; then
    # Directory scans skip our own -k outputs; an explicitly named file is
    # always honoured, .min.png or not.
    if [ $recurse -eq 1 ]; then
      while IFS= read -r -d '' f; do files+=("$f"); done \
        < <(find "$p" -type f -iname '*.png' ! -iname '*.min.png' -print0)
    else
      while IFS= read -r -d '' f; do files+=("$f"); done \
        < <(find "$p" -maxdepth 1 -type f -iname '*.png' ! -iname '*.min.png' -print0)
    fi
  else
    echo "minify-png: no such file or directory: $p" >&2
    exit 1
  fi
done

if [ ${#files[@]} -eq 0 ]; then
  echo "minify-png: no PNG files found." >&2
  exit 0
fi

# ---- process ---------------------------------------------------------------
work="$(mktemp -d -t minifypng)"
trap 'rm -rf "$work"' EXIT
tmp="$work/candidate.png"

total_before=0
total_after=0
changed=0
scanned=0

for src in "${files[@]}"; do
  # Only real PNGs get through: quantizing a mislabelled JPEG would silently
  # no-op and report "already optimal". Redirection dodges dash-led filenames.
  sig=$(head -c 8 < "$src" | od -An -tx1 | tr -d ' \n')
  if [ "$sig" != "89504e470d0a1a0a" ]; then
    printf '  !  %-42s not a PNG — skipped\n' "$src"
    continue
  fi

  before=$(($(wc -c < "$src")))
  scanned=$((scanned + 1))

  # Stage 1: lossy quantization (or a plain copy if pngquant is absent or the
  # quality floor can't be met — pngquant exits non-zero and writes nothing).
  if [ $have_pngquant -eq 1 ] \
    && pngquant --quality="$quality" --strip --force --output "$tmp" -- "$src" 2>/dev/null; then
    :
  else
    cp -f -- "$src" "$tmp"
  fi

  # Stage 2: lossless recompression in place.
  if [ $have_oxipng -eq 1 ]; then
    oxipng --quiet -o 4 --strip safe "$tmp" 2>/dev/null || true
  fi

  after=$(($(wc -c < "$tmp")))

  if [ "$after" -ge "$before" ]; then
    total_before=$((total_before + before))
    total_after=$((total_after + before))
    printf '  =  %-42s %s  already optimal\n' "$src" "$(human "$before")"
    continue
  fi

  pct=$(((before - after) * 100 / before))
  total_before=$((total_before + before))
  total_after=$((total_after + after))
  changed=$((changed + 1))

  if [ $dry -eq 1 ]; then
    printf '  ~  %-42s %s -> %s  (would save %d%%)\n' \
      "$src" "$(human "$before")" "$(human "$after")" "$pct"
  elif [ $keep -eq 1 ]; then
    # Strip only a real .png suffix — %.* would chop at a dot in a directory
    # name when an explicitly passed file has no extension.
    case "$src" in
      *.[Pp][Nn][Gg]) dest="${src%.*}.min.png" ;;
      *) dest="$src.min.png" ;;
    esac
    cp -f -- "$tmp" "$dest"
    printf '  +  %-42s %s -> %s  (-%d%%)\n' \
      "$dest" "$(human "$before")" "$(human "$after")" "$pct"
  else
    cp -f -- "$tmp" "$src"
    printf '  v  %-42s %s -> %s  (-%d%%)\n' \
      "$src" "$(human "$before")" "$(human "$after")" "$pct"
  fi
done

echo
if [ $changed -eq 0 ]; then
  echo "Nothing to do — $scanned file(s) already optimal."
else
  pct=$(((total_before - total_after) * 100 / total_before))
  if [ $dry -eq 1 ]; then
    printf 'Dry run: %d of %d file(s) would shrink, %s -> %s (-%d%% overall).\n' \
      "$changed" "$scanned" "$(human "$total_before")" "$(human "$total_after")" "$pct"
  else
    printf 'Done: shrank %d of %d file(s), %s -> %s (-%d%% overall).\n' \
      "$changed" "$scanned" "$(human "$total_before")" "$(human "$total_after")" "$pct"
  fi
fi
