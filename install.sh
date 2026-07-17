#!/usr/bin/env bash
# zed-cp installer. Builds the listener, installs scripts/templates to
# ~/.config/zed-cp, merges Zed tasks/keymap/snippets (without clobbering), and
# installs a login service so the Competitive Companion listener is always up.
#
# Usage: ./install.sh [--root DIR]
#   --root DIR   problem folder (default: ~/cp, or $ZED_CP_ROOT)
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed-cp"
ZED_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
BIN_DIR="$CONFIG_DIR/bin"
TPL_DIR="$CONFIG_DIR/templates"
EXEC="$CONFIG_DIR/cp-listener"

ROOT="${ZED_CP_ROOT:-$HOME/cp}"
ROOT_SET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; ROOT_SET=1; shift 2 ;;
    -h|--help) echo "usage: ./install.sh [--root DIR]"; exit 0 ;;
    *) echo "unknown arg: $1"; exit 1 ;;
  esac
done

# Prompt for the problem folder if not given and running interactively.
if [ "$ROOT_SET" = "0" ] && [ -t 0 ]; then
  printf 'Problem folder [%s]: ' "$ROOT"
  read -r reply
  [ -n "$reply" ] && ROOT="$reply"
fi
# expand leading ~
case "$ROOT" in "~"/*) ROOT="$HOME/${ROOT#~/}" ;; "~") ROOT="$HOME" ;; esac

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*"; }

command -v go >/dev/null 2>&1 || { echo "go is required to build the listener (https://go.dev/dl)"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required for config merge"; exit 1; }

say "Building listener"
mkdir -p "$CONFIG_DIR"
( cd "$REPO/listener" && go build -o "$EXEC" . )

say "Installing scripts + templates to $CONFIG_DIR"
mkdir -p "$BIN_DIR" "$TPL_DIR"
cp "$REPO"/bin/*.sh "$BIN_DIR/"
chmod +x "$BIN_DIR"/*.sh
cp "$REPO"/templates/*.cpp "$TPL_DIR/"

say "Writing config ($CONFIG_DIR/config)"
cat > "$CONFIG_DIR/config" <<EOF
# zed-cp config. Edit and restart the listener service to apply.
ZED_CP_ROOT="$ROOT"
ZED_CP_TEMPLATE_DIR="$TPL_DIR"
# ZED_CP_COMPILER="g++"     # auto-detected if unset
# ZED_CP_STD="c++17"
# ZED_CP_FLAGS="-O2 -Wall"
# ZED_CLI="/path/to/zed"    # auto-detected if unset
EOF
mkdir -p "$ROOT"

say "Merging Zed config in $ZED_DIR"
mkdir -p "$ZED_DIR/snippets"
BIN_DIR="$BIN_DIR" TPL_DIR="$TPL_DIR" ZED_DIR="$ZED_DIR" REPO="$REPO" CONFIG_DIR="$CONFIG_DIR" python3 - <<'PY'
import json, os, sys, re

zed = os.environ["ZED_DIR"]
binp = os.environ["BIN_DIR"]
tpl  = os.environ["TPL_DIR"]
repo = os.environ["REPO"]
cfg  = os.environ["CONFIG_DIR"]

def load(path):
    if not os.path.exists(path):
        return None, False
    try:
        with open(path) as f:
            return json.load(f), True
    except Exception:
        return None, None  # exists but unparseable (comments/JSON5)

def save(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

manual = []

# --- tasks.json ---
tasks_frag = json.load(open(f"{repo}/zed/tasks.json"))
for t in tasks_frag:
    t["command"] = t["command"].replace("__BIN__", binp)
tp = f"{zed}/tasks.json"
cur, ok = load(tp)
if ok is None:
    manual.append(("tasks.json", tasks_frag))
else:
    cur = cur if isinstance(cur, list) else []
    ours = {t["label"] for t in tasks_frag}
    cur = [t for t in cur if t.get("label") not in ours]  # drop stale cp:* for idempotency
    save(tp, cur + tasks_frag)
    print("  tasks.json merged")

# --- keymap.json ---
km_frag = json.load(open(f"{repo}/zed/keymap.json"))[0]  # single Workspace block
kp = f"{zed}/keymap.json"
cur, ok = load(kp)
if ok is None:
    manual.append(("keymap.json", [km_frag]))
else:
    cur = cur if isinstance(cur, list) else []
    ws = next((b for b in cur if b.get("context") == "Workspace"), None)
    if ws is None:
        cur.append(km_frag)
    else:
        ws.setdefault("bindings", {}).update(km_frag["bindings"])
    save(kp, cur)
    print("  keymap.json merged")

# --- snippets/cpp.json (generated from templates) ---
def body(path):
    lines = open(path).read().splitlines()
    out = []
    for i, l in enumerate(lines):
        out.append(l)
        if l.strip() == "void solve() {" and i+1 < len(lines) and lines[i+1].strip() == "":
            out.append("    $0")
    res, skip = [], False
    for l in out:
        if l == "    $0":
            res.append(l); skip = True; continue
        if skip and l.strip() == "":
            skip = False; continue
        skip = False; res.append(l)
    return res

usaco = ["#include <bits/stdc++.h>","using namespace std;","","void solve() {","    $0","}","",
         "int main() {","    ios::sync_with_stdio(false); cin.tie(nullptr);","    solve();","}",""]
snips = {
  "CP_No_Test": {"prefix": "cp",    "body": body(f"{tpl}/template.cpp"),       "description": "CP template (single test)"},
  "CP_Test":    {"prefix": "cpt",   "body": body(f"{tpl}/template-multi.cpp"), "description": "CP template (multitest)"},
  "usaco":      {"prefix": "usaco", "body": usaco,                             "description": "USACO template"},
}
sp = f"{zed}/snippets/cpp.json"
cur, ok = load(sp)
if ok is None:
    manual.append(("snippets/cpp.json", snips))
else:
    cur = cur if isinstance(cur, dict) else {}
    cur.update(snips)
    save(sp, cur)
    print("  snippets/cpp.json merged")

# unparseable existing files: write fragments aside for manual merge
if manual:
    frag_dir = os.path.join(cfg, "zed-fragments")
    os.makedirs(frag_dir, exist_ok=True)
    for name, data in manual:
        p = os.path.join(frag_dir, name.replace("/", "_"))
        save(p, data)
    print("MANUAL:" + ",".join(n for n, _ in manual) + "|" + frag_dir)
PY

# --- service ---
OS="$(uname -s)"
if [ "${ZED_CP_SKIP_SERVICE:-0}" = "1" ]; then
  say "ZED_CP_SKIP_SERVICE=1, skipping service install"
  OS="skip"
fi
if [ "$OS" = "Darwin" ]; then
  say "Installing launchd service"
  PLIST="$HOME/Library/LaunchAgents/com.zed-cp.listener.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  sed -e "s|__EXEC__|$EXEC|g" -e "s|__ROOT__|$ROOT|g" -e "s|__TEMPLATE_DIR__|$TPL_DIR|g" \
    "$REPO/service/macos.plist.template" > "$PLIST"
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load "$PLIST"
  say "listener loaded (launchd)"
elif [ "$OS" = "Linux" ]; then
  say "Installing systemd user service"
  UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$UNIT_DIR"
  sed -e "s|__EXEC__|$EXEC|g" -e "s|__ROOT__|$ROOT|g" -e "s|__TEMPLATE_DIR__|$TPL_DIR|g" \
    "$REPO/service/linux.service.template" > "$UNIT_DIR/zed-cp-listener.service"
  systemctl --user daemon-reload
  systemctl --user enable --now zed-cp-listener.service
  say "listener enabled (systemd --user)"
elif [ "$OS" = "skip" ]; then
  :
else
  warn "unknown OS '$OS'; run the listener manually: $EXEC"
fi

echo
say "Done. Problem root: $ROOT"
cat <<EOF

Next:
  1. Install the Competitive Companion browser extension.
  2. Restart Zed (or reload config) to pick up tasks/keymap/snippets.
  3. Click the green (+) on a problem page -> files appear + open in Zed.

Keybinds (hyperkey = ctrl-alt-shift-cmd):
  hyper-j  judge      hyper-r  run(stdin)   hyper-m  add test
  hyper-n  new prob   hyper-i  toggle multitest
Snippets: type  cp / cpt / usaco  then Tab.

Uninstall: ./uninstall.sh
EOF
