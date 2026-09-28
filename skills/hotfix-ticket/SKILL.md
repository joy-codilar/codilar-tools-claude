---
name: hotfix-ticket
description: "Quick pipeline for a small Jira fix. Opus confirms it's really small and shapes the fix, sonnet or haiku does the work, then it verifies with tests, pushes hotfix/<KEY>, opens a GitLab MR and comments on Jira. No plan/work files. Use when the user runs /codilar:hotfix-ticket <JIRA-KEY>."
argument-hint: "<JIRA-KEY>"
disable-model-invocation: true
model: sonnet
---

# Hotfix Jira ticket $ARGUMENTS

Plugin references folder (`REFS`): `${CLAUDE_SKILL_DIR}/../../references`

**Before doing anything else**, read these two files in full and follow them for the whole run:
1. `REFS/run-rules.md`
2. `REFS/hotfix-pipeline.md`

You're the orchestrator. The `codilar:engineering-standards` skill applies to everything you and your agents do: think like a senior architect and challenge the ask, check the impact on other areas, DRY, human tone with no em-dashes.

`<ID>` = `$ARGUMENTS` (the Jira key). If no key was given, ask for one. Then run the hotfix pipeline from Step 0, reading the ticket yourself in Step 1.

Project config:
!`cat .claude/delivery.json 2>/dev/null || echo "NOT_CONFIGURED"`

Git state:
!`git status --short --branch 2>/dev/null | head -15`

Code index (run rules section 6):
!`if ! command -v graphify >/dev/null 2>&1; then echo NOT_INSTALLED; elif [ -f graphify-out/graph.json ]; then echo READY; else echo NO_GRAPH; fi`
