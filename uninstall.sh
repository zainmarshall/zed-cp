#!/usr/bin/env bash
# Remove the zed-cp listener service, installed files, and the cp: entries it
# added to your Zed config. Your problem folder is never touched.
#
# Usage: ./uninstall.sh [--keep-config]
set -u
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed-cp"
ZED_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
KEEP_CONFIG=0
[ "${1:-}" = "--keep-config" ] && KEEP_CONFIG=1

# load config so we strip the exact (possibly customized) keys/snippet file
PREFIX="ctrl-alt-shift-cmd"; EXT="cpp"; LANG="cpp"
ZED_CP_KEY_JUDGE=j; ZED_CP_KEY_RUN=r; ZED_CP_KEY_ADDTEST=m; ZED_CP_KEY_NEWPROB=n; ZED_CP_KEY_TOGGLE=i
# shellcheck disable=SC1090,SC1091
[ -f "$CONFIG_DIR/config" ] && . "$CONFIG_DIR/config"
PREFIX="${ZED_CP_KEYS_PREFIX:-$PREFIX}"; EXT="${ZED_CP_EXT:-$EXT}"; LANG="${ZED_CP_LANG:-$LANG}"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  PLIST="$HOME/Library/LaunchAgents/com.zed-cp.listener.plist"
  launchctl bootout "gui/$(id -u)/com.zed-cp.listener" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"; say "removed launchd service"
elif [ "$OS" = "Linux" ]; then
  systemctl --user disable --now zed-cp-listener.service 2>/dev/null || true
  rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/zed-cp-listener.service"
  systemctl --user daemon-reload 2>/dev/null || true; say "removed systemd service"
fi
pkill -f "zed-cp/cp-listener" 2>/dev/null || true

if [ "$KEEP_CONFIG" = "0" ] && command -v python3 >/dev/null 2>&1; then
  say "Removing cp: entries from Zed config"
  ZED_DIR="$ZED_DIR" PREFIX="$PREFIX" EXT="$EXT" LANG="$LANG" \
  KJ="$ZED_CP_KEY_JUDGE" KR="$ZED_CP_KEY_RUN" KM="$ZED_CP_KEY_ADDTEST" KN="$ZED_CP_KEY_NEWPROB" KI="$ZED_CP_KEY_TOGGLE" \
  python3 - <<'PY'
import json, os
zed=os.environ["ZED_DIR"]; prefix=os.environ["PREFIX"]; ext=os.environ["EXT"]; lang=os.environ["LANG"]
TASKS={"cp: judge","cp: run (stdin)","cp: add test","cp: new problem","cp: toggle multitest"}
KEYS={f"{prefix}-{os.environ[k]}" for k in ("KJ","KR","KM","KN","KI")}
SNIPS={"CP_No_Test","CP_Test","usaco"}
SFILE={"cpp":"cpp","c":"c","py":"python","java":"java"}.get(ext,ext)
def edit(path, fn):
    if not os.path.exists(path): return
    try: d=json.load(open(path))
    except Exception: print(f"  skip {os.path.basename(path)} (JSON5, edit by hand)"); return
    d=fn(d); json.dump(d, open(path,"w"), indent=2); open(path,"a").write("\n"); print(f"  cleaned {os.path.basename(path)}")
edit(f"{zed}/tasks.json", lambda d:[t for t in d if t.get("label") not in TASKS] if isinstance(d,list) else d)
def km(d):
    if not isinstance(d,list): return d
    out=[]
    for b in d:
        if b.get("context")=="Workspace" and isinstance(b.get("bindings"),dict):
            b["bindings"]={k:v for k,v in b["bindings"].items() if k not in KEYS}
            if not b["bindings"]: continue
        out.append(b)
    return out
edit(f"{zed}/keymap.json", km)
edit(f"{zed}/snippets/{SFILE}.json", lambda d:{k:v for k,v in d.items() if k not in SNIPS} if isinstance(d,dict) else d)
PY
fi

rm -rf "$CONFIG_DIR"; say "removed $CONFIG_DIR"
echo; echo "Done. Your problem folder was not touched. Restart Zed to drop the keybinds."
