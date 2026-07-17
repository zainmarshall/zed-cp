#!/usr/bin/env bash
# Prompt for a problem name, create <dir>/<name>.cpp from template + first test,
# open source + test files in Zed. Meant to run in a Zed terminal task.
# Usage: newprob.sh [dir]   (dir defaults to current dir)
set -u
DIR0="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$DIR0/lib.sh"

DIR="${1:-$PWD}"
[ -z "$DIR" ] && DIR="$PWD"

read -rp "problem name: " name
[ -z "${name:-}" ] && { echo "cancelled"; exit 1; }
BASE="$(basename "$name" .cpp)"
SRC="$DIR/$BASE.cpp"
TDIR="$DIR/tests/$BASE"
mkdir -p "$TDIR"

TPL="$ZED_CP_TEMPLATE_DIR/template.cpp"
if [ ! -f "$SRC" ]; then
  if [ -f "$TPL" ]; then cp "$TPL" "$SRC"
  else printf '#include <bits/stdc++.h>\nusing namespace std;\nint main(){\n    \n}\n' > "$SRC"; fi
fi
[ -e "$TDIR/1.in" ] || { : > "$TDIR/1.in"; : > "$TDIR/1.out"; }

echo "created $SRC"
open_in_zed "$SRC" "$TDIR/1.in" "$TDIR/1.out"
