# Logic for style-guard.sh. Reads the PreToolUse hook JSON on stdin.
import json, os, re, sys

EM = "\u2014"
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = data.get("tool_name", "")
inp = data.get("tool_input", {}) or {}

def block(where):
    sys.stderr.write(
        "BLOCKED by codilar style guard: new em-dash (U+2014) in %s. "
        "Rewrite that text without it: use a comma, colon, brackets or a new sentence. "
        "Keep the tone plain and human.\n" % where)
    sys.exit(2)

def count(s):
    return (s or "").count(EM)

if tool == "Write":
    path = inp.get("file_path", "")
    before = 0
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            before = count(f.read())
    except Exception:
        pass
    if count(inp.get("content")) > before:
        block(path or "the file")

elif tool == "Edit":
    if count(inp.get("new_string")) > count(inp.get("old_string")):
        block(inp.get("file_path", "the edit"))

elif tool == "MultiEdit":
    for e in inp.get("edits", []) or []:
        if count(e.get("new_string")) > count(e.get("old_string")):
            block(inp.get("file_path", "the edit"))

elif tool == "Bash":
    cmd = inp.get("command", "")
    if EM in cmd and re.search(r"\b(git\s+(commit|tag|notes)|glab\s+(mr|issue)|gh\s+pr)\b", cmd):
        block("a commit / MR command")

elif tool.startswith("mcp__"):
    # Only write-type tools on Jira/Confluence/GitLab servers.
    if re.search(r"(atlassian|jira|confluence|gitlab)", tool, re.I) and \
       re.search(r"(comment|create|update|edit|add|transition|post|note)", tool, re.I):
        if EM in json.dumps(inp, ensure_ascii=False):
            block("a Jira / GitLab write")

sys.exit(0)
