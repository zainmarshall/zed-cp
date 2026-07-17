#!/usr/bin/env bash
# Compile (if needed) and run a source with stdin from the terminal.
# Usage: run.sh <source>
set -u
DIR0="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$DIR0/lib.sh"

SRC="${1:?need source file}"
BIN="$(mktemp)"

if [ -n "$ZED_CP_COMPILE" ]; then
  if ! eval "$(cp_subst "$ZED_CP_COMPILE" "$SRC" "$BIN")"; then
    echo "compile failed"; rm -f "$BIN"; exit 1
  fi
fi
eval "$(cp_subst "$ZED_CP_RUN" "$SRC" "$BIN")"
rm -f "$BIN"
