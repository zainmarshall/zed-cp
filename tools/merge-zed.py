#!/usr/bin/env python3
"""Merge zed-cp tasks/keymap/snippets into the user's Zed config without
clobbering. Driven by env vars set by install.sh. Files that are unparseable
(comments/JSON5) are left alone and written to CONFIG_DIR/zed-fragments."""
import json, os

zed  = os.environ["ZED_DIR"]
binp = os.environ["BIN_DIR"]
tpl  = os.environ["TPL_DIR"]
repo = os.environ["REPO"]
cfg  = os.environ["CONFIG_DIR"]
ext  = os.environ.get("EXT", "cpp")
lang = os.environ.get("LANG_SEL", "cpp")
prefix = os.environ.get("PREFIX", "ctrl-alt-shift-cmd")
keys = {
    "cp: judge":           os.environ.get("KJ", "j"),
    "cp: run (stdin)":     os.environ.get("KR", "r"),
    "cp: add test":        os.environ.get("KM", "m"),
    "cp: new problem":     os.environ.get("KN", "n"),
    "cp: toggle multitest":os.environ.get("KI", "i"),
}

manual = []

def load(path):
    if not os.path.exists(path):
        return None, True
    try:
        with open(path) as f:
            return json.load(f), True
    except Exception:
        return None, False

def save(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2); f.write("\n")

# ---- tasks.json ----
frag = json.load(open(f"{repo}/zed/tasks.json"))
for t in frag:
    t["command"] = t["command"].replace("__BIN__", binp)
tp = f"{zed}/tasks.json"
cur, ok = load(tp)
if not ok:
    manual.append(("tasks.json", frag))
else:
    cur = cur if isinstance(cur, list) else []
    ours = {t["label"] for t in frag}
    cur = [t for t in cur if t.get("label") not in ours]
    save(tp, cur + frag); print("  tasks.json merged")

# ---- keymap.json ----
bindings = {f"{prefix}-{k}": ["task::Spawn", {"task_name": label}] for label, k in keys.items()}
kp = f"{zed}/keymap.json"
cur, ok = load(kp)
block = {"context": "Workspace", "bindings": bindings}
if not ok:
    manual.append(("keymap.json", [block]))
else:
    cur = cur if isinstance(cur, list) else []
    ws = next((b for b in cur if b.get("context") == "Workspace"), None)
    if ws is None:
        cur.append(block)
    else:
        ws.setdefault("bindings", {}).update(bindings)
    save(kp, cur); print("  keymap.json merged")

# ---- snippets ----
def body(path):
    if not os.path.exists(path):
        return None
    lines = open(path).read().splitlines()
    for i, l in enumerate(lines):
        st = l.strip()
        opens = "solve" in st and (st.endswith("{") or st.endswith(":"))
        if opens and i + 1 < len(lines):
            indent = " " * (len(l) - len(l.lstrip()) + 4)
            nxt = lines[i + 1].strip()
            if nxt == "" or nxt == "pass":
                lines[i + 1] = indent + "$0"
            else:
                lines.insert(i + 1, indent + "$0")
            return lines
    lines.append("$0")
    return lines

SNIPPET_FILE = {"cpp": "cpp", "c": "c", "py": "python", "java": "java"}.get(ext, ext)
snips = {}
b1 = body(f"{tpl}/template.{ext}")
b2 = body(f"{tpl}/template-multi.{ext}")
if b1: snips["CP_No_Test"] = {"prefix": "cp",  "body": b1, "description": "CP template (single test)"}
if b2: snips["CP_Test"]    = {"prefix": "cpt", "body": b2, "description": "CP template (multitest)"}
if lang == "cpp":
    snips["usaco"] = {"prefix": "usaco", "body": [
        "#include <bits/stdc++.h>", "using namespace std;", "", "void solve() {", "    $0", "}", "",
        "int main() {", "    ios::sync_with_stdio(false); cin.tie(nullptr);", "    solve();", "}", ""],
        "description": "USACO template"}
if snips:
    sp = f"{zed}/snippets/{SNIPPET_FILE}.json"
    cur, ok = load(sp)
    if not ok:
        manual.append((f"snippets/{SNIPPET_FILE}.json", snips))
    else:
        cur = cur if isinstance(cur, dict) else {}
        cur.update(snips); save(sp, cur); print(f"  snippets/{SNIPPET_FILE}.json merged")

# ---- unparseable files: write fragments aside ----
if manual:
    fd = os.path.join(cfg, "zed-fragments")
    os.makedirs(fd, exist_ok=True)
    for name, data in manual:
        save(os.path.join(fd, name.replace("/", "_")), data)
    print("  NOTE: some Zed files have comments/JSON5; fragments written to " + fd)
