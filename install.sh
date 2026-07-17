#!/usr/bin/env bash
# zed-cp guided installer. Builds the listener, installs scripts/templates to
# ~/.config/zed-cp, merges Zed tasks/keymap/snippets (without clobbering), and
# installs a login service. Interactive by default; flags skip the prompts.
#
# Flags (all optional):
#   --root DIR       problem folder
#   --lang LANG      cpp | c | python | java
#   --compile CMD    compile template ({src} {bin} {dir} {base}); "" for none
#   --run CMD        run template
#   --prefix MODS    hotkey modifier prefix (e.g. ctrl-alt-shift-cmd)
#   --yes            accept all defaults, no prompts
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed-cp"
ZED_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
BIN_DIR="$CONFIG_DIR/bin"
TPL_DIR="$CONFIG_DIR/templates"
EXEC="$CONFIG_DIR/cp-listener"

BOLD='\033[1m'; DIM='\033[2m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; RESET='\033[0m'
step_n=0
step() { step_n=$((step_n+1)); printf "\n${BOLD}${CYAN}[%d]${RESET} ${BOLD}%s${RESET}\n" "$step_n" "$1"; }
info() { printf "  ${DIM}%s${RESET}\n" "$1"; }
ok()   { printf "  ${GREEN}checkmark${RESET} %s\n" "$1" | sed 's/checkmark/\xE2\x9C\x93/'; }
warn() { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }
ask()  { # ask <var> <prompt> <default>
  local __v __d="$3" __r
  if [ "$YES" = "1" ] || [ ! -t 0 ]; then printf -v "$1" '%s' "$__d"; return; fi
  printf "  ${BOLD}%s${RESET} ${DIM}[%s]${RESET}: " "$2" "$__d"; read -r __r
  printf -v "$1" '%s' "${__r:-$__d}"
}

# defaults / flag values
ROOT="${ZED_CP_ROOT:-$HOME/cp}"; ROOT_SET=0
LANG_SEL=""; COMPILE_SET=""; RUN_SET=""; PREFIX="ctrl-alt-shift-cmd"; YES=0
while [ $# -gt 0 ]; do case "$1" in
  --root) ROOT="$2"; ROOT_SET=1; shift 2;;
  --lang) LANG_SEL="$2"; shift 2;;
  --compile) COMPILE_SET="$2"; COMPILE_GIVEN=1; shift 2;;
  --run) RUN_SET="$2"; shift 2;;
  --prefix) PREFIX="$2"; shift 2;;
  --yes|-y) YES=1; shift;;
  -h|--help) sed -n '2,15p' "$0"; exit 0;;
  *) echo "unknown arg: $1"; exit 1;;
esac; done

command -v go >/dev/null 2>&1 || { echo "go is required (https://go.dev/dl)"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required"; exit 1; }

printf "\n  ${BOLD}${CYAN}zed-cp installer${RESET}\n"

# ---- language ----
step "Language"
if [ -z "$LANG_SEL" ]; then
  if [ "$YES" = "1" ] || [ ! -t 0 ]; then LANG_SEL="cpp"; else
    info "1) C++   2) C   3) Python   4) Java"
    ask CHOICE "choose" "1"
    case "$CHOICE" in 1|cpp) LANG_SEL=cpp;; 2|c) LANG_SEL=c;; 3|python|py) LANG_SEL=python;; 4|java) LANG_SEL=java;; *) LANG_SEL=cpp;; esac
  fi
fi
# detect a real C/C++ compiler for defaults
CXX=g++; for c in g++-15 g++-14 g++-13 g++-12 g++-11 g++ clang++; do command -v "$c" >/dev/null 2>&1 && { CXX="$c"; break; }; done
CC=gcc;  for c in gcc-15 gcc-14 gcc-13 gcc-12 gcc-11 gcc clang; do command -v "$c" >/dev/null 2>&1 && { CC="$c"; break; }; done
case "$LANG_SEL" in
  cpp)    EXT=cpp;  DEF_COMPILE="$CXX -std=c++17 -O2 -Wall {src} -o {bin}"; DEF_RUN="{bin}";;
  c)      EXT=c;    DEF_COMPILE="$CC -std=c11 -O2 -Wall {src} -o {bin}";    DEF_RUN="{bin}";;
  python) EXT=py;   DEF_COMPILE="";                                        DEF_RUN="python3 {src}";;
  java)   EXT=java; DEF_COMPILE="javac -d {dir} {src}";                     DEF_RUN="java -cp {dir} Main";;
  *) echo "unknown lang: $LANG_SEL"; exit 1;;
esac
ok "language: $LANG_SEL (.$EXT)"

# ---- folder ----
step "Problem folder"
[ "$ROOT_SET" = "0" ] && ask ROOT "problem folder" "$ROOT"
case "$ROOT" in "~"/*) ROOT="$HOME/${ROOT#~/}";; "~") ROOT="$HOME";; esac
ok "$ROOT"

# ---- compile / run ----
step "Compile & run commands"
info "placeholders: {src} {bin} {dir} {base}"
COMPILE="${COMPILE_SET}"; [ "${COMPILE_GIVEN:-0}" = "1" ] || { ask COMPILE "compile (empty = none)" "$DEF_COMPILE"; }
RUN="${RUN_SET:-}"; [ -n "$RUN" ] || ask RUN "run" "$DEF_RUN"
ok "compile: ${COMPILE:-<none>}"
ok "run:     $RUN"

# ---- hotkeys ----
step "Hotkeys"
KJ=j; KR=r; KM=m; KN=n; KI=i
ask PREFIX "modifier prefix" "$PREFIX"
if [ "$YES" != "1" ] && [ -t 0 ]; then
  ask CUSTOM "customize per-key letters? (y/N)" "N"
  if [ "$CUSTOM" = "y" ] || [ "$CUSTOM" = "Y" ]; then
    ask KJ "judge key" "$KJ"; ask KR "run key" "$KR"; ask KM "add-test key" "$KM"
    ask KN "new-problem key" "$KN"; ask KI "toggle-multitest key" "$KI"
  fi
fi
ok "prefix: $PREFIX  (judge=$KJ run=$KR addtest=$KM newprob=$KN toggle=$KI)"

# ---- build ----
step "Building listener"
mkdir -p "$CONFIG_DIR" "$BIN_DIR" "$TPL_DIR"
( cd "$REPO/listener" && go build -o "$EXEC" . )
ok "built $EXEC"

# ---- install files ----
step "Installing scripts + templates ($CONFIG_DIR)"
cp "$REPO"/bin/*.sh "$BIN_DIR/"; chmod +x "$BIN_DIR"/*.sh
# templates: copy only if missing so your customized template survives reinstall
for t in "$REPO"/templates/*.*; do
  dst="$TPL_DIR/$(basename "$t")"
  [ -f "$dst" ] || cp "$t" "$dst"
done
cat > "$CONFIG_DIR/config" <<EOF
# zed-cp config. Edit, then restart the listener:
#   macOS:  launchctl kickstart -k gui/\$(id -u)/com.zed-cp.listener
#   Linux:  systemctl --user restart zed-cp-listener
ZED_CP_ROOT="$ROOT"
ZED_CP_LANG="$LANG_SEL"
ZED_CP_EXT="$EXT"
ZED_CP_COMPILE="$COMPILE"
ZED_CP_RUN="$RUN"
ZED_CP_TEMPLATE_DIR="$TPL_DIR"
ZED_CP_OPEN="source"   # what the listener opens on parse: none | source | all
ZED_CP_TEMPLATE="cp"   # which template to stamp: cp (single) | cpt (multitest)
ZED_CP_KEYS_PREFIX="$PREFIX"
ZED_CP_KEY_JUDGE="$KJ"
ZED_CP_KEY_RUN="$KR"
ZED_CP_KEY_ADDTEST="$KM"
ZED_CP_KEY_NEWPROB="$KN"
ZED_CP_KEY_TOGGLE="$KI"
EOF
mkdir -p "$ROOT"
ok "config written"

# ---- merge Zed config ----
step "Merging Zed config ($ZED_DIR)"
mkdir -p "$ZED_DIR/snippets"
BIN_DIR="$BIN_DIR" TPL_DIR="$TPL_DIR" ZED_DIR="$ZED_DIR" REPO="$REPO" CONFIG_DIR="$CONFIG_DIR" \
LANG_SEL="$LANG_SEL" EXT="$EXT" PREFIX="$PREFIX" KJ="$KJ" KR="$KR" KM="$KM" KN="$KN" KI="$KI" \
python3 "$REPO/tools/merge-zed.py"

# ---- service ----
step "Service"
OS="$(uname -s)"
if [ "${ZED_CP_SKIP_SERVICE:-0}" = "1" ]; then OS="skip"; info "skipped (ZED_CP_SKIP_SERVICE=1)"; fi
if [ "$OS" = "Darwin" ]; then
  PLIST="$HOME/Library/LaunchAgents/com.zed-cp.listener.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  sed -e "s|__EXEC__|$EXEC|g" "$REPO/service/macos.plist.template" > "$PLIST"
  U="$(id -u)"
  launchctl bootout "gui/$U/com.zed-cp.listener" 2>/dev/null || true
  launchctl bootstrap "gui/$U" "$PLIST" 2>/dev/null || { launchctl unload "$PLIST" 2>/dev/null || true; launchctl load "$PLIST"; }
  ok "listener running (launchd)"
elif [ "$OS" = "Linux" ]; then
  UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"; mkdir -p "$UNIT_DIR"
  sed -e "s|__EXEC__|$EXEC|g" "$REPO/service/linux.service.template" > "$UNIT_DIR/zed-cp-listener.service"
  systemctl --user daemon-reload; systemctl --user enable --now zed-cp-listener.service
  ok "listener running (systemd --user)"
elif [ "$OS" != "skip" ]; then
  warn "unknown OS '$OS'; run manually: $EXEC"
fi

printf "\n${BOLD}${GREEN}Done.${RESET} root: %s   lang: %s\n" "$ROOT" "$LANG_SEL"
cat <<EOF

  Install Competitive Companion, restart Zed, click (+) on a problem.
  Hotkeys ($PREFIX): $KJ judge  $KR run  $KM add test  $KN new problem  $KI toggle multitest
  Edit template: $TPL_DIR/template.$EXT
  Reconfigure:   re-run ./install.sh      Uninstall: ./uninstall.sh
EOF
