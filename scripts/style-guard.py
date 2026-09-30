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

# Projects that set "aiVisibility": false in .claude/delivery.json must not show
# AI involvement: no attribution trailers, no "generated with" lines, no emojis.
def ai_hidden():
    cfg = os.path.join(os.environ.get("CLAUDE_PROJECT_DIR", "."), ".claude", "delivery.json")
    try:
        with open(cfg, encoding="utf-8") as f:
            return json.load(f).get("aiVisibility") is False
    except Exception:
        return False

HIDDEN = ai_hidden()
TRACE = re.compile(r"co-authored-by:\s*claude|generated with \[?claude|claude\.com/claude-code|noreply@anthropic\.com", re.I)
EMOJI = re.compile("[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F1E6-\U0001F1FF]")

def traces(s):
    s = s or ""
    return len(TRACE.findall(s)) + len(EMOJI.findall(s))

def block_hidden(where):
    sys.stderr.write(
        "BLOCKED by codilar style guard: this project hides AI involvement (aiVisibility: false), "
        "and %s adds an emoji or an AI attribution line (Co-Authored-By: Claude, 'Generated with Claude Code'). "
        "Remove it and write it the way a developer on the team would.\n" % where)
    sys.exit(2)

def check(old, new, where):
    if count(new) > count(old):
        block(where)
    if HIDDEN and traces(new) > traces(old):
        block_hidden(where)

if tool == "Write":
    path = inp.get("file_path", "")
    before_text = ""
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            before_text = f.read()
    except Exception:
        pass
    check(before_text, inp.get("content"), path or "the file")

elif tool == "Edit":
    check(inp.get("old_string"), inp.get("new_string"), inp.get("file_path", "the edit"))

elif tool == "MultiEdit":
    for e in inp.get("edits", []) or []:
        check(e.get("old_string"), e.get("new_string"), inp.get("file_path", "the edit"))

elif tool == "Bash":
    cmd = inp.get("command", "")
    if re.search(r"\b(git\s+(commit|tag|notes)|glab\s+(mr|issue)|gh\s+pr)\b", cmd):
        check("", cmd, "a commit / MR command")

elif tool.startswith("mcp__"):
    # Only write-type tools on Jira/Confluence/GitLab servers.
    if re.search(r"(atlassian|jira|confluence|gitlab)", tool, re.I) and \
       re.search(r"(comment|create|update|edit|add|transition|post|note)", tool, re.I):
        check("", json.dumps(inp, ensure_ascii=False), "a Jira / GitLab write")

sys.exit(0)
