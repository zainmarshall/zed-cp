#!/usr/bin/env bash
# Compile a C++ source and run it against ALL its tests.
# Tests live at <dir>/tests/<basename>/N.in  (+ optional N.out).
# Usage: judge.sh <source.cpp>
set -u
DIR0="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$DIR0/lib.sh"

SRC="${1:?need source file}"
DIR="$(dirname "$SRC")"
BASE="$(basename "$SRC")"; BASE="${BASE%.*}"
TDIR="$DIR/tests/$BASE"
BIN="$(mktemp)"

# shellcheck disable=SC2086
if ! "$ZED_CP_COMPILER" -std="$ZED_CP_STD" $ZED_CP_FLAGS "$SRC" -o "$BIN"; then
  echo "compile failed"; exit 1
fi

shopt -s nullglob
tests=($(ls "$TDIR"/*.in 2>/dev/null | sort -V))
if [ ${#tests[@]} -eq 0 ]; then
  echo "no tests in $TDIR"; rm -f "$BIN"; exit 1
fi

norm() { tr -s '[:space:]' ' ' | sed 's/^ *//;s/ *$//'; }

pass=0; fail=0
for in in "${tests[@]}"; do
  n=$(basename "$in" .in)
  exp="$TDIR/$n.out"
  got=$("$BIN" < "$in")
  if [ -f "$exp" ] && diff -q <(printf '%s' "$got" | norm) <(norm < "$exp") >/dev/null; then
    echo "test $n: PASS"; pass=$((pass+1))
  else
    echo "test $n: FAIL"; fail=$((fail+1))
    echo "  --- input ---";    sed 's/^/  /' "$in"
    echo "  --- expected ---"; [ -f "$exp" ] && sed 's/^/  /' "$exp"
    echo "  --- got ---";      printf '%s\n' "$got" | sed 's/^/  /'
  fi
done
echo "== $pass passed, $fail failed =="
rm -f "$BIN"
