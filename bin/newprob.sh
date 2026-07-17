#!/usr/bin/env bash
# Prompt for a problem name, create <dir>/<name>.<ext> from the template + first
# test, open source + test files in Zed. Meant to run in a Zed terminal task.
# Usage: newprob.sh [dir]   (dir defaults to current dir)
set -u
DIR0="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$DIR0/lib.sh"

DIR="${1:-$PWD}"
[ -z "$DIR" ] && DIR="$PWD"

read -rp "problem name: " name
[ -z "${name:-}" ] && { echo "cancelled"; exit 1; }
BASE="$(basename "$name" ".$ZED_CP_EXT")"
SRC="$DIR/$BASE.$ZED_CP_EXT"
TDIR="$DIR/tests/$BASE"
mkdir -p "$TDIR"

TPL="$ZED_CP_TEMPLATE_DIR/template.$ZED_CP_EXT"
if [ ! -f "$SRC" ]; then
  if [ -f "$TPL" ]; then cp "$TPL" "$SRC"; else : > "$SRC"; fi
fi
[ -e "$TDIR/1.in" ] || { : > "$TDIR/1.in"; : > "$TDIR/1.out"; }

echo "created $SRC"
open_in_zed "$SRC" "$TDIR/1.in" "$TDIR/1.out"
