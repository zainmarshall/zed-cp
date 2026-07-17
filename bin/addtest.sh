#!/usr/bin/env bash
# Add a test case for a source file (auto-numbered), open both files in Zed.
# Usage: addtest.sh <source.cpp>
set -u
DIR0="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$DIR0/lib.sh"

SRC="${1:?need source file}"
DIR="$(dirname "$SRC")"
BASE="$(basename "$SRC")"; BASE="${BASE%.*}"
TDIR="$DIR/tests/$BASE"
mkdir -p "$TDIR"

n=1
while [ -e "$TDIR/$n.in" ]; do n=$((n+1)); done
: > "$TDIR/$n.in"
: > "$TDIR/$n.out"

echo "created test $n in $TDIR"
open_in_zed "$TDIR/$n.in" "$TDIR/$n.out"
