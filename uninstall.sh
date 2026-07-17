#!/usr/bin/env bash
# Remove the zed-cp listener service and installed files. Leaves your problem
# folder and merged Zed config entries alone (remove those by hand if wanted).
set -u
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed-cp"

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  PLIST="$HOME/Library/LaunchAgents/com.zed-cp.listener.plist"
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
  echo "removed launchd service"
elif [ "$OS" = "Linux" ]; then
  systemctl --user disable --now zed-cp-listener.service 2>/dev/null || true
  rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/zed-cp-listener.service"
  systemctl --user daemon-reload 2>/dev/null || true
  echo "removed systemd service"
fi

pkill -f "cp-listener" 2>/dev/null || true
rm -rf "$CONFIG_DIR"
echo "removed $CONFIG_DIR"
echo
echo "Note: Zed tasks/keymap/snippets entries (labels starting 'cp:') were left in place."
echo "      Your problem folder was not touched."
