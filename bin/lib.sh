#!/usr/bin/env bash
# Shared config for zed-cp scripts. Sourced by judge/addtest/newprob/toggle.
# Resolves settings from (in order): env vars, config file, sane defaults.

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed-cp"
CONFIG_FILE="$CONFIG_DIR/config"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

# Root folder where problems live.
ZED_CP_ROOT="${ZED_CP_ROOT:-$HOME/cp}"

# C++ compiler: honor env/config, else first available. Prefer real GCC
# (versioned) over a plain "g++" that may be a clang alias (macOS), then clang++.
if [ -z "${ZED_CP_COMPILER:-}" ]; then
  for c in g++-15 g++-14 g++-13 g++-12 g++-11 g++ clang++; do
    if command -v "$c" >/dev/null 2>&1; then ZED_CP_COMPILER="$c"; break; fi
  done
fi
ZED_CP_COMPILER="${ZED_CP_COMPILER:-g++}"
ZED_CP_STD="${ZED_CP_STD:-c++17}"
ZED_CP_FLAGS="${ZED_CP_FLAGS:--O2 -Wall}"

# Directory holding template.cpp / template-multi.cpp (this repo's templates/).
ZED_CP_TEMPLATE_DIR="${ZED_CP_TEMPLATE_DIR:-$CONFIG_DIR/templates}"

# Locate the Zed CLI across platforms. Empty if not found (scripts skip opening).
zed_cli() {
  if [ -n "${ZED_CLI:-}" ] && [ -x "$ZED_CLI" ]; then echo "$ZED_CLI"; return; fi
  for cand in zed zeditor; do
    if command -v "$cand" >/dev/null 2>&1; then command -v "$cand"; return; fi
  done
  local mac="/Applications/Zed.app/Contents/MacOS/cli"
  [ -x "$mac" ] && { echo "$mac"; return; }
  echo ""
}

# Open files in Zed (tab order as given), focus the first. No-op if no CLI.
open_in_zed() {
  local cli; cli="$(zed_cli)"
  [ -z "$cli" ] && return
  "$cli" "$@" >/dev/null 2>&1 || true
  "$cli" "$1" >/dev/null 2>&1 || true
}
