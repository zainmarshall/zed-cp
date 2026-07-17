#!/usr/bin/env bash
# Toggle the current file's main() between single-test and multitest.
# Usage: toggle-multitest.sh <source.cpp>
set -u
DIR0="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$DIR0/lib.sh"
SRC="${1:?need source file}"

case "$ZED_CP_LANG" in
  cpp|c) : ;;
  *) echo "toggle-multitest only supports C/C++ (solve()/main() form)"; exit 0 ;;
esac

python3 - "$SRC" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
single = "    ios::sync_with_stdio(false); cin.tie(nullptr);\n    solve();"
multi  = "    ios::sync_with_stdio(false); cin.tie(nullptr);\n    int tc; cin >> tc;\n    while(tc--) solve();"
if multi in s:
    s = s.replace(multi, single); print("-> single-test")
elif single in s:
    s = s.replace(single, multi); print("-> multitest")
else:
    print("no recognizable main() to toggle"); sys.exit(0)
open(p, "w").write(s)
PY
