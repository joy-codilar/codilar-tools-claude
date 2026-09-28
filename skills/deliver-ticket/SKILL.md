---
name: deliver-ticket
description: "Full delivery pipeline for a Jira ticket. Reads the ticket and everything related, asks questions, plans and waits for approval, then builds with stack agents in parallel, tests, reviews, pushes feature/<KEY> or task/<KEY>, opens a GitLab MR, writes .claude/plans and .claude/work records and comments on Jira. Use when the user runs /codilar:deliver-ticket <JIRA-KEY>."
argument-hint: "<JIRA-KEY>"
disable-model-invocation: true
model: opus
---

# Deliver Jira ticket $ARGUMENTS

Plugin references folder (`REFS`): `${CLAUDE_SKILL_DIR}/../../references`

**Before doing anything else**, read these two files in full and follow them for the whole run:
1. `REFS/run-rules.md`
2. `REFS/full-pipeline.md`

You're the orchestrator. The `codilar:engineering-standards` skill applies to everything you and your agents do: think like a senior architect and challenge the ask, check the impact on other areas, DRY, human tone with no em-dashes.

`<ID>` = `$ARGUMENTS` (the Jira key). If no key was given, ask for one.

Intake is done by `ticket-analyst` in Phase 1 of the full pipeline. Run the full pipeline from Phase 0.

Project config:
!`cat .claude/delivery.json 2>/dev/null || echo "NOT_CONFIGURED"`

Git state:
!`git status --short --branch 2>/dev/null | head -15`

Code index (run rules section 6):
!`if ! command -v graphify >/dev/null 2>&1; then echo NOT_INSTALLED; elif [ -f graphify-out/graph.json ]; then echo READY; else echo NO_GRAPH; fi`
