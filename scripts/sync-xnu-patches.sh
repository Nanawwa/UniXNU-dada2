#!/usr/bin/env bash
#
# Refresh this repository's vendored xnu patch series.
#
# This board does not write to the reset UniXNU or to xnu-linux-toolchain (both are read
# only to us), so the series it applies has to be carried here. `unixnu` resolves a module
# name to exactly one tree with `setdefault`, and the device repository is resolved first:
# naming a patch module `xnu` here would *replace* the base module wholesale, not extend it.
# Vendoring the bytes is therefore the only way to get base + toolchain + board patches in
# one glob-sorted `patches/xnu/` (build-xnu-4k-baseline.sh applies it with `find | sort`).
#
#   scripts/sync-xnu-patches.sh [--prune] [--check]
#
#   base      UniXNU/patches/xnu/*.patch                 (the portability + platform series)
#   toolchain xnu-linux-toolchain/patches/xnu/*.patch    (the Linux host tool series)
#   board     scripts here that begin with zzzz-dada-    (kept, never overwritten)
#
# The sources are disjoint by name today (base 56, toolchain 5, board 2). If a name ever
# collides the toolchain copy wins the last write; --check reports it.
#
# --check writes nothing and exits non-zero when a copy is stale or missing.
# --prune reports vendored patches that no source provides any more (never deletes).
#
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DADA_ROOT=$(cd "$REPO/.." && pwd)

BASE_REPO=${UNIXNU_BASE_REPO:-$DADA_ROOT/UniXNU}
TOOLCHAIN_REPO=${XNU_LINUX_REPO:-$DADA_ROOT/xnu-linux-toolchain}
DEST=$REPO/patches/xnu

PRUNE=0
CHECK=0
for arg in "$@"; do
  case "$arg" in
    --prune) PRUNE=1 ;;
    --check) CHECK=1 ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "sync-xnu-patches.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [ ! -d "$DEST" ]; then
  echo "sync-xnu-patches.sh: $DEST does not exist" >&2
  exit 1
fi

stale=0
same=0
synced=0
declare -A SOURCE_OF

# Board patches are authored here and must survive; they are not copied from anywhere.
for patch in "$DEST"/zzzz-dada-*.patch; do
  [ -e "$patch" ] || continue
  SOURCE_OF["$(basename "$patch")"]="dada"
done

copy_series() {
  local label=$1 dir=$2
  if [ ! -d "$dir" ]; then
    echo "sync-xnu-patches.sh: $label series not found: $dir" >&2
    return 1
  fi
  local patch name src
  for patch in "$dir"/*.patch; do
    [ -e "$patch" ] || continue
    name=$(basename "$patch")
    if [ -n "${SOURCE_OF[$name]:-}" ] && [ "${SOURCE_OF[$name]}" != "$label" ]; then
      echo "collision $name: $label overwrites ${SOURCE_OF[$name]}" >&2
    fi
    SOURCE_OF["$name"]=$label
    src=$DEST/$name
    if [ -f "$src" ] && cmp -s "$patch" "$src"; then
      same=$((same + 1))
      continue
    fi
    if [ "$CHECK" = 1 ]; then
      if [ -f "$src" ]; then
        echo "stale  $label/$name"
      else
        echo "missing $label/$name"
      fi
      stale=$((stale + 1))
    else
      cp "$patch" "$src"
      echo "synced $label/$name"
      synced=$((synced + 1))
    fi
  done
}

copy_series base "$BASE_REPO/patches/xnu"
copy_series toolchain "$TOOLCHAIN_REPO/patches/xnu"

# The Linux firehose builder is a build script, not a patch, but the same rule applies:
# the build tree's scripts/ is assembled from base scripts first and this repository
# second, so a same-named copy here is exactly what replaces base's xcodebuild-only one.
FIREHOSE_SRC=$TOOLCHAIN_REPO/scripts/build-firehose-linux.sh
FIREHOSE_DST=$REPO/scripts/build-firehose-linux.sh
if [ -f "$FIREHOSE_SRC" ]; then
  if [ -f "$FIREHOSE_DST" ] && cmp -s "$FIREHOSE_SRC" "$FIREHOSE_DST"; then
    same=$((same + 1))
  elif [ "$CHECK" = 1 ]; then
    echo "stale  toolchain/build-firehose-linux.sh"
    stale=$((stale + 1))
  else
    cp "$FIREHOSE_SRC" "$FIREHOSE_DST"
    echo "synced toolchain/build-firehose-linux.sh"
    synced=$((synced + 1))
  fi
fi

if [ "$PRUNE" = 1 ]; then
  for patch in "$DEST"/*.patch; do
    [ -e "$patch" ] || continue
    name=$(basename "$patch")
    if [ -z "${SOURCE_OF[$name]:-}" ]; then
      echo "prune  $name (no source provides it; kept)"
    fi
  done
fi

echo "sync-xnu-patches.sh: $same unchanged, $synced synced, $stale stale"
if [ "$CHECK" = 1 ] && [ "$stale" != 0 ]; then
  exit 1
fi