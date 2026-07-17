# zed-cp

Competitive programming in [Zed](https://zed.dev): fetch problems from the browser, run your solution against sample tests with one keybind, all inside the editor.

Zed has no equivalent of VS Code's [cph](https://github.com/agrawal-d/cph) or Neovim's [CompetiTest](https://github.com/xeluxee/competitest.nvim), and its extension API can't build one (no panels/webviews). `zed-cp` fills the gap with Zed **tasks + keybinds + snippets** plus a tiny background listener for [Competitive Companion](https://github.com/jmerle/competitive-companion).

## What you get

- **Fetch problems**: click Competitive Companion's green (+) on any problem page. `zed-cp` writes the source file + sample tests and opens them in Zed.
- **Judge**: one keybind compiles the open file and diffs its output against every sample test (token-wise, whitespace-tolerant).
- **New problem / add test**: scaffold files without leaving the editor.
- **Snippets**: `cp`, `cpt` (multitest), `usaco` templates. Toggle a file between single/multitest with a keybind.

## Requirements

- [Zed](https://zed.dev), [Go](https://go.dev) (to build the listener), Python 3, a C++ compiler (`g++`/`clang++`)
- [Competitive Companion](https://github.com/jmerle/competitive-companion) browser extension
- macOS (launchd) or Linux (systemd user service)

## Install

```bash
git clone https://github.com/<you>/zed-cp && cd zed-cp
./install.sh --root ~/cp      # --root sets your problem folder (default ~/cp)
```

Then restart Zed and install Competitive Companion. That's it.

The installer builds the listener, copies scripts/templates to `~/.config/zed-cp`, **merges** (never overwrites) your Zed `tasks.json` / `keymap.json` / `snippets/cpp.json`, and installs a login service so the listener is always running. If a config file has comments/JSON5 the merge can't parse, it writes the fragment to `~/.config/zed-cp/zed-fragments/` and tells you to paste it in.

## Usage

| Keybind (hyper = `ctrl-alt-shift-cmd`) | Action |
|---|---|
| `hyper-j` | judge open file vs sample tests |
| `hyper-r` | compile + run, type stdin |
| `hyper-m` | add a test case |
| `hyper-n` | new problem (prompts for name) |
| `hyper-i` | toggle single ↔ multitest |

Snippets: type `cp` / `cpt` / `usaco` then `Tab`.

Layout on disk:

```
<root>/<group>/<name>.cpp
<root>/<group>/tests/<name>/1.in  1.out  2.in  2.out ...
```

## Config

`~/.config/zed-cp/config`:

```sh
ZED_CP_ROOT="$HOME/cp"          # problem folder
ZED_CP_COMPILER="g++"           # auto-detected if unset
ZED_CP_STD="c++17"
ZED_CP_FLAGS="-O2 -Wall"
ZED_CLI="/path/to/zed"          # auto-detected if unset
```

Restart the listener after editing:

```bash
# macOS
launchctl kickstart -k gui/$(id -u)/com.zed-cp.listener
# Linux
systemctl --user restart zed-cp-listener
```

Default the listener to multitest templates by adding `ZED_CP_TEMPLATE=cpt` to the service environment.

## Uninstall

```bash
./uninstall.sh
```

Removes the service and `~/.config/zed-cp`. Leaves your problem folder and the `cp:` entries in your Zed config (remove those by hand if you want).

## How it works

The listener is a ~100-line Go HTTP server on port 27121 (Competitive Companion's default). It writes files and shells out to the Zed CLI to open them. Judging is a shell script driven by Zed tasks; keybinds spawn those tasks. No editor extension required.

## License

MIT
