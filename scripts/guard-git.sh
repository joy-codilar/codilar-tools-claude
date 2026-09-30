#!/usr/bin/env bash
# PreToolUse guard for Bash commands (shipped with the codilar plugin).
# Blocks: pushes/commits to protected branches, force pushes, and destructive Magento commands.
# Exit 2 = block the tool call; stderr is shown to Claude so it can correct course.

payload="$(cat)"

# Extract tool_input.command from the hook JSON (python3 if present, grep fallback).
cmd=""
if command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$payload" | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception:
    pass' 2>/dev/null)"
fi
[ -z "$cmd" ] && cmd="$payload"

block() { echo "BLOCKED by codilar guard: $1" >&2; exit 2; }

# Protected branches: defaults + the project's targetBranch from .claude/delivery.json
protected="main|master|develop|staging|production|release"
cfg="${CLAUDE_PROJECT_DIR:-.}/.claude/delivery.json"
if [ -f "$cfg" ]; then
  for tb in $(grep -oE '"(targetBranch|hotfixTargetBranch)"[[:space:]]*:[[:space:]]*"[^"]+"' "$cfg" | sed -E 's/.*"([^"]+)"$/\1/'); do
    protected="$protected|$(printf '%s' "$tb" | sed 's/[.[\*^$/]/\\&/g')"
  done
fi

if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+push'; then
  if printf '%s' "$cmd" | grep -Eq '[[:space:]](-f|--force)([[:space:]]|$)'; then
    block "force push is not allowed (use --force-with-lease on your own task/feature branch if really needed)."
  fi
  if printf '%s' "$cmd" | grep -Eq "git[[:space:]]+push([[:space:]]+[^;&|]*)?[[:space:]:+]($protected)([[:space:];&|]|$)"; then
    block "pushing to a protected branch ($protected). Push to task/<ID> or feature/<ID> and open an MR instead."
  fi
fi

if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+(commit|merge|rebase)([[:space:]]|$)'; then
  cur="$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ -n "$cur" ] && printf '%s' "$cur" | grep -Eq "^($protected)$"; then
    block "you are on protected branch '$cur'. Create/checkout task/<ID> or feature/<ID> first."
  fi
fi

# aiVisibility false: .claude/ must never be committed.
if [ -f "$cfg" ] && grep -Eq '"aiVisibility"[[:space:]]*:[[:space:]]*false' "$cfg"; then
  if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+add([[:space:]][^;&|]*)?[[:space:]](-f|--force)[[:space:]][^;&|]*\.claude'; then
    block "this project keeps .claude/ out of git (aiVisibility: false). Don't force-add it."
  fi
  if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
    if git -C "${CLAUDE_PROJECT_DIR:-.}" diff --cached --name-only 2>/dev/null | grep -q '^\.claude/'; then
      block "files under .claude/ are staged, and this project keeps .claude/ out of git (aiVisibility: false). Unstage them with: git restore --staged .claude"
    fi
  fi
fi

if printf '%s' "$cmd" | grep -Eq 'bin/magento[[:space:]]+(setup:uninstall|setup:rollback|setup:backup|app:config:import|setup:store-config:set)'; then
  block "destructive/global Magento command. Ask the user to run it manually if it is really needed."
fi

if printf '%s' "$cmd" | grep -Eqi '(drop[[:space:]]+(database|schema)|truncate[[:space:]]+table)'; then
  block "destructive database command."
fi

exit 0
