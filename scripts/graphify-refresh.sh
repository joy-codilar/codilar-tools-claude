#!/usr/bin/env bash
# PostToolUse hook (codilar plugin): keeps the graphify code index current after
# every Write/Edit to a code file. Does nothing unless graphify is installed and
# the project already has graphify-out/graph.json (the pipelines build it).
# The rebuild runs detached so edits never wait on it. A lock plus a dirty flag
# collapse a burst of edits into one or two rebuilds. Always exits 0.

payload="$(cat)"
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
out="$dir/graphify-out"

command -v graphify >/dev/null 2>&1 || exit 0
[ -f "$out/graph.json" ] || exit 0

file=""
if command -v python3 >/dev/null 2>&1; then
  file="$(printf '%s' "$payload" | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
except Exception:
    pass' 2>/dev/null)"
fi
[ -n "$file" ] || exit 0

# Only files inside this project, and only the code types graphify indexes.
case "$file" in "$dir"/*|[!/]*) ;; *) exit 0 ;; esac
case "$file" in */graphify-out/*) exit 0 ;; esac
case "$(printf '%s' "${file##*.}" | tr '[:upper:]' '[:lower:]')" in
  php|py|ts|tsx|js|jsx|mjs|cjs|go|rs|java|kt|kts|swift|rb|cs|scala|c|cc|cpp|cxx|h|hpp|lua) ;;
  *) exit 0 ;;
esac

lock="$out/.codilar-refresh.lock"
dirty="$out/.codilar-refresh.dirty"
log="$out/.codilar-refresh.log"

# A lock older than 15 minutes means a worker died; clear it.
if [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +15 2>/dev/null)" ]; then
  rmdir "$lock" 2>/dev/null
fi

touch "$dirty"
mkdir "$lock" 2>/dev/null || exit 0   # a worker is running and will pick up the flag

worker() {
  while :; do
    while [ -e "$dirty" ]; do
      rm -f "$dirty"
      (cd "$dir" && graphify update .) >"$log" 2>&1
    done
    rmdir "$lock" 2>/dev/null
    # An edit may have landed between the last check and releasing the lock.
    [ -e "$dirty" ] || break
    mkdir "$lock" 2>/dev/null || break
  done
}

worker </dev/null >/dev/null 2>&1 &
disown 2>/dev/null
exit 0
