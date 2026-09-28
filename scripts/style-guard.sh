#!/usr/bin/env bash
# PreToolUse guard (codilar plugin): stops agents adding em-dashes to code, docs,
# commit messages, MR descriptions and Jira comments. Existing em-dashes in a file
# are left alone; only new ones are blocked.
# Exit 2 = block, and stderr goes back to Claude so it rewrites the text.

command -v python3 >/dev/null 2>&1 || exit 0
exec python3 "$(dirname "$0")/style-guard.py"
