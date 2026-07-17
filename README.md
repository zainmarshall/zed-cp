# zed-cp

Competitive programming in [Zed](https://zed.dev): fetch problems from the browser, run your solution against sample tests with one keybind, all inside the editor.

Zed has no equivalent of VS Code's [cph](https://github.com/agrawal-d/cph) or Neovim's [CompetiTest](https://github.com/xeluxee/competitest.nvim), and its extension API can't build one (no panels/webviews). `zed-cp` fills the gap with Zed **tasks + keybinds + snippets** plus a tiny background listener for [Competitive Companion](https://github.com/jmerle/competitive-companion).

## What you get

- **Fetch problems**: click Competitive Companion's green (+) on any problem page. `zed-cp` writes the source file + sample tests and opens them in Zed.
- **Judge**: one keybind compiles the open file and diffs its output against every sample test (token-wise, whitespace-tolerant).
- **New problem / add test**: scaffold files without leaving the editor.
- **Snippets**: `cp`, `cpt` (multitest), `usaco` templates. Toggle a file between single/multitest with a keybind.
- **Any language**: C++, C, Python, Java out of the box, or set your own compile/run commands. Everything (language, template, compile command, folder, hotkeys) is configurable at install or later.

## Requirements

- [Zed](https://zed.dev), [Go](https://go.dev) (to build the listener), Python 3, a C++ compiler (`g++`/`clang++`)
- [Competitive Companion](https://github.com/jmerle/competitive-companion) browser extension
- macOS (launchd) or Linux (systemd user service)

## Install

```bash
git clone https://github.com/zainmarshall/zed-cp && cd zed-cp
./install.sh                  # guided: language, folder, compile/run, hotkeys
```

The installer walks you through language, problem folder, compile/run commands,
and hotkeys (Enter accepts each default). Non-interactive:

```bash
./install.sh --yes --lang cpp --root ~/cp
./install.sh --yes --lang python --prefix cmd-alt
./install.sh --lang java --compile "javac -d {dir} {src}" --run "java -cp {dir} Main"
```

Flags: `--lang cpp|c|python|java`, `--root DIR`, `--compile CMD`, `--run CMD`
(placeholders `{src} {bin} {dir} {base}`), `--prefix MODS`, `--yes`.

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

Re-run `./install.sh` any time to reconfigure, or edit `~/.config/zed-cp/config`:

```sh
ZED_CP_ROOT="$HOME/cp"                       # problem folder
ZED_CP_LANG="cpp"                            # cpp | c | python | java
ZED_CP_EXT="cpp"                             # source file extension
ZED_CP_COMPILE="g++ -std=c++17 -O2 -Wall {src} -o {bin}"  # "" for interpreted
ZED_CP_RUN="{bin}"                           # e.g. "python3 {src}"
ZED_CP_TEMPLATE_DIR="$HOME/.config/zed-cp/templates"
ZED_CP_KEYS_PREFIX="ctrl-alt-shift-cmd"      # hotkey modifier prefix
ZED_CP_KEY_JUDGE="j"                          # + _RUN _ADDTEST _NEWPROB _TOGGLE
# ZED_CP_TEMPLATE="cpt"                       # stamp multitest by default
# ZED_CLI="/path/to/zed"                      # auto-detected if unset
```

Command templates use `{src} {bin} {dir} {base}`. Scripts read the config live;
restart the listener after changing root/template/language:

```bash
# macOS
launchctl kickstart -k gui/$(id -u)/com.zed-cp.listener
# Linux
systemctl --user restart zed-cp-listener
```

Edit your template at `~/.config/zed-cp/templates/template.<ext>` (and
`template-multi.<ext>` for the multitest variant). Changing hotkeys means editing
`~/.config/zed/keymap.json` or re-running the installer.

## Uninstall

```bash
./uninstall.sh                 # removes service, files, and cp: entries from Zed config
./uninstall.sh --keep-config   # keep the Zed tasks/keymap/snippets entries
```

Removes the service, `~/.config/zed-cp`, and the `cp:` tasks/keybinds/snippets it added to your Zed config. Your problem folder is never touched. (Config files with comments/JSON5 are skipped with a note; edit those by hand.)

## How it works

The listener is a ~100-line Go HTTP server on port 27121 (Competitive Companion's default). It writes files and shells out to the Zed CLI to open them. Judging is a shell script driven by Zed tasks; keybinds spawn those tasks. No editor extension required.

## License

MIT
