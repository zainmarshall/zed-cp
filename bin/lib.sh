#!/usr/bin/env bash
# Shared config for zed-cp scripts. Sourced by judge/run/addtest/newprob/toggle.
# Resolves settings from (in order): env vars, config file, sane defaults.
#
# Command templates use placeholders: {src} {bin} {dir} {base}
#   {src}  path to the source file
#   {bin}  path to a temp compiled binary (compiled languages)
#   {dir}  directory of the source file
#   {base} source file name without extension

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed-cp"
CONFIG_FILE="$CONFIG_DIR/config"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

ZED_CP_ROOT="${ZED_CP_ROOT:-$HOME/cp}"
ZED_CP_LANG="${ZED_CP_LANG:-cpp}"
ZED_CP_EXT="${ZED_CP_EXT:-cpp}"
ZED_CP_TEMPLATE_DIR="${ZED_CP_TEMPLATE_DIR:-$CONFIG_DIR/templates}"

# expand a leading ~ so we never create a literal "~" directory
cp_untilde() { case "$1" in "~") echo "$HOME";; "~"/*) echo "$HOME/${1#~/}";; *) echo "$1";; esac; }
ZED_CP_ROOT="$(cp_untilde "$ZED_CP_ROOT")"
ZED_CP_TEMPLATE_DIR="$(cp_untilde "$ZED_CP_TEMPLATE_DIR")"

# C++ compiler for the default compile command. Prefer real GCC (versioned) over
# a plain "g++" that may be a clang alias (macOS), then clang++.
if [ -z "${ZED_CP_COMPILER:-}" ]; then
  for c in g++-15 g++-14 g++-13 g++-12 g++-11 g++ clang++; do
    if command -v "$c" >/dev/null 2>&1; then ZED_CP_COMPILER="$c"; break; fi
  done
fi
ZED_CP_COMPILER="${ZED_CP_COMPILER:-g++}"
ZED_CP_STD="${ZED_CP_STD:-c++17}"
ZED_CP_FLAGS="${ZED_CP_FLAGS:--O2 -Wall}"

# Compile / run command templates. Default to C++. Interpreted languages set
# ZED_CP_COMPILE="" and a ZED_CP_RUN like "python3 {src}".
# NOTE: assign with explicit if, not ${VAR:-default} -- the {bin}/{src}
# placeholders contain "}" which would prematurely close the expansion.
if [ -z "${ZED_CP_COMPILE+set}" ]; then
  ZED_CP_COMPILE="$ZED_CP_COMPILER -std=$ZED_CP_STD $ZED_CP_FLAGS {src} -o {bin}"
fi
if [ -z "${ZED_CP_RUN+set}" ]; then
  ZED_CP_RUN="{bin}"
fi

# Substitute placeholders in a command template. Args: template src bin
cp_subst() {
  printf '%s' "$1" | sed \
    -e "s|{src}|$2|g" \
    -e "s|{bin}|$3|g" \
    -e "s|{dir}|$(dirname "$2")|g" \
    -e "s|{base}|$(basename "${2%.*}")|g"
}

# Locate the Zed CLI across platforms. Empty if not found.
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
