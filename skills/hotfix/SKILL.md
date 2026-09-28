---
name: hotfix
description: "Quick pipeline for a small fix without a Jira ticket. Asks for the problem, has opus confirm it's small and shape the fix, then sonnet or haiku does it, verifies with tests, pushes hotfix/<name> and opens a GitLab MR. No plan/work files. Use when the user runs /codilar:hotfix, optionally followed by a description."
argument-hint: "[what is broken / what to change]"
disable-model-invocation: true
model: sonnet
---

# Hotfix (no Jira ticket)

Plugin references folder (`REFS`): `${CLAUDE_SKILL_DIR}/../../references`

**Before doing anything else**, read these two files in full and follow them for the whole run:
1. `REFS/run-rules.md`
2. `REFS/hotfix-pipeline.md`

You're the orchestrator. The `codilar:engineering-standards` skill applies to everything you and your agents do: think like a senior architect and challenge the ask, check the impact on other areas, DRY, human tone with no em-dashes.

Problem given with the command: `$ARGUMENTS`

If that's empty or unclear, ask the user in plain text: what's broken or what needs to change, where (URL, page, API, screen), how to reproduce it, and what the correct behaviour should be.

Then pick `<ID>`: a short kebab-case name (e.g. `fix-minicart-qty`). Run the hotfix pipeline from Step 0. Skip every Jira step.

Project config:
!`cat .claude/delivery.json 2>/dev/null || echo "NOT_CONFIGURED"`

Git state:
!`git status --short --branch 2>/dev/null | head -15`

Code index (run rules section 6):
!`if ! command -v graphify >/dev/null 2>&1; then echo NOT_INSTALLED; elif [ -f graphify-out/graph.json ]; then echo READY; else echo NO_GRAPH; fi`
