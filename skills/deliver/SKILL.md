---
name: deliver
description: "Full delivery pipeline without a Jira ticket. Asks the user for the requirement, then plans with approval, builds with stack agents in parallel, tests, reviews, pushes a branch, opens a GitLab MR and writes .claude/plans and .claude/work records. Use when the user runs /codilar:deliver, optionally followed by a description."
argument-hint: "[requirement description]"
disable-model-invocation: true
model: opus
---

# Deliver (no Jira ticket)

Plugin references folder (`REFS`): `${CLAUDE_SKILL_DIR}/../../references`

**Before doing anything else**, read these two files in full and follow them for the whole run:
1. `REFS/run-rules.md`
2. `REFS/full-pipeline.md`

You're the orchestrator. The `codilar:engineering-standards` skill applies to everything you and your agents do: think like a senior architect and challenge the ask, check the impact on other areas, DRY, human tone with no em-dashes.

## Intake
Requirement given with the command: `$ARGUMENTS`

If that's empty or too thin to plan from, ask the user to supply the requirement. Ask in plain text so they can type or paste freely:
- what needs to change, and why (the business goal)
- acceptance criteria: how we'll know it's done
- pages, URLs, screens or APIs involved, and any designs or reference links
- constraints: deadline, things that must not change, store views or locales

Once you have it, pick `<ID>`: a short kebab-case name for the task (e.g. `pdp-stock-badge`). Check that `.claude/plans/<ID>.md` doesn't already exist for a different task. Then run the full pipeline from Phase 0, and in Phase 1 run `ticket-analyst` in no-ticket mode with the requirement text. The branch type (feature or task) becomes one of the questionnaire questions.

No Jira steps in this pipeline: skip every Jira transition and comment.

Project config:
!`cat .claude/delivery.json 2>/dev/null || echo "NOT_CONFIGURED"`

Git state:
!`git status --short --branch 2>/dev/null | head -15`
