#!/usr/bin/env bash
# Compile (if the language needs it) and run a source against ALL its tests.
# Tests live at <dir>/tests/<basename>/N.in  (+ optional N.out).
# Works for any language via ZED_CP_COMPILE / ZED_CP_RUN templates (see lib.sh).
# Usage: judge.sh <source>
set -u
DIR0="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$DIR0/lib.sh"

SRC="${1:?need source file}"
DIR="$(dirname "$SRC")"
BASE="$(basename "$SRC")"; BASE="${BASE%.*}"
TDIR="$DIR/tests/$BASE"
BIN="$(mktemp)"

if [ -n "$ZED_CP_COMPILE" ]; then
  if ! eval "$(cp_subst "$ZED_CP_COMPILE" "$SRC" "$BIN")"; then
    echo "compile failed"; rm -f "$BIN"; exit 1
  fi
fi
RUNCMD="$(cp_subst "$ZED_CP_RUN" "$SRC" "$BIN")"

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
  got=$(eval "$RUNCMD" < "$in")
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
