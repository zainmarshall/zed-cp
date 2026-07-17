#!/usr/bin/env bash
# Remove the zed-cp listener service, installed files, and the cp: entries it
# added to your Zed config. Your problem folder is never touched.
#
# Usage: ./uninstall.sh [--keep-config]
#   --keep-config   leave the cp: tasks/keymap/snippets in your Zed config
set -u
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed-cp"
ZED_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
KEEP_CONFIG=0
[ "${1:-}" = "--keep-config" ] && KEEP_CONFIG=1

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*"; }

# --- service ---
OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  PLIST="$HOME/Library/LaunchAgents/com.zed-cp.listener.plist"
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
  say "removed launchd service"
elif [ "$OS" = "Linux" ]; then
  systemctl --user disable --now zed-cp-listener.service 2>/dev/null || true
  rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/zed-cp-listener.service"
  systemctl --user daemon-reload 2>/dev/null || true
  say "removed systemd service"
fi

pkill -f "zed-cp/cp-listener" 2>/dev/null || true

# --- Zed config entries ---
if [ "$KEEP_CONFIG" = "0" ] && command -v python3 >/dev/null 2>&1; then
  say "Removing cp: entries from Zed config"
  ZED_DIR="$ZED_DIR" python3 - <<'PY'
import json, os
zed = os.environ["ZED_DIR"]
OURS_TASKS = {"cp: judge","cp: run (stdin)","cp: add test","cp: new problem","cp: toggle multitest"}
OURS_KEYS  = {"ctrl-alt-shift-cmd-j","ctrl-alt-shift-cmd-r","ctrl-alt-shift-cmd-m","ctrl-alt-shift-cmd-n","ctrl-alt-shift-cmd-i"}
OURS_SNIPS = {"CP_No_Test","CP_Test","usaco"}

def edit(path, fn):
    if not os.path.exists(path): return
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print(f"  skip {os.path.basename(path)} (has comments/JSON5, edit by hand)"); return
    data = fn(data)
    with open(path, "w") as f:
        json.dump(data, f, indent=2); f.write("\n")
    print(f"  cleaned {os.path.basename(path)}")

edit(f"{zed}/tasks.json", lambda d: [t for t in d if t.get("label") not in OURS_TASKS] if isinstance(d, list) else d)

def clean_keymap(d):
    if not isinstance(d, list): return d
    out = []
    for b in d:
        if b.get("context") == "Workspace" and isinstance(b.get("bindings"), dict):
            b["bindings"] = {k: v for k, v in b["bindings"].items() if k not in OURS_KEYS}
            if not b["bindings"]: continue  # drop now-empty block
        out.append(b)
    return out
edit(f"{zed}/keymap.json", clean_keymap)

edit(f"{zed}/snippets/cpp.json", lambda d: {k: v for k, v in d.items() if k not in OURS_SNIPS} if isinstance(d, dict) else d)
PY
else
  [ "$KEEP_CONFIG" = "1" ] && say "leaving Zed config entries (--keep-config)"
fi

rm -rf "$CONFIG_DIR"
say "removed $CONFIG_DIR"
echo
echo "Done. Your problem folder was not touched."
echo "Restart Zed to drop the removed tasks/keybinds."
