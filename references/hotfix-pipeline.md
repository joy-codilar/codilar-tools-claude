# Hotfix pipeline (hotfix and hotfix-ticket)

The quick path for small, well-understood fixes. Opus is used once, to confirm the task really is small and to shape the fix. Sonnet (or haiku for trivial edits) does the work. **No `.claude/plans` or `.claude/work` files**: context travels in the agent prompts, and the record is the MR description (plus the Jira comment for tickets).

`REFS` is this plugin's `references/` folder (the skill gives you its path). `<ID>` is the Jira key, or a short kebab-case name for `hotfix`. Follow `REFS/run-rules.md` for the whole run.

## Step 0: Preflight
- `.claude/delivery.json` missing, or no `targetBranch`: run `codilar:setup-project` first.
- Uncommitted changes: ask whether to stash them, commit them first, or abort.
- Hotfix base and target branch: `hotfixTargetBranch` from config, falling back to `targetBranch`.

## Step 1: Intake
- **hotfix-ticket:** read the Jira issue and its comments yourself (it's a small ticket, so no analyst agent needed). Skim linked issues only if they look relevant.
- **hotfix:** you already have the user's description from the skill.

## Step 2: Triage (agent: `hotfix-triage`, opus)
Pass it the ask (ticket text or user description) and `delivery.json`. It finds the code, confirms the root cause, checks the impact on other areas and returns:
- **verdict:** `HOTFIX` or `TOO_BIG`, with the reason
- root cause, the fix (files and changes), reuse notes, affected areas, the tests to add or run
- questions, if anything is unclear or it thinks there's a better approach
- the agent to use: the stack developer (sonnet), or `chore-developer` (haiku) for a trivial edit

**If the verdict is TOO_BIG:** tell the user why, and suggest `codilar:deliver-ticket` / `codilar:deliver` (AskUserQuestion: switch, or continue as a hotfix anyway). If they switch, follow `REFS/full-pipeline.md`, reusing what triage found.

## Step 3: Mini-plan approval (gate)
Show the user a short mini-plan in chat: cause, fix, files, tests, affected areas. Ask any questions from triage in the same message (AskUserQuestion). **Wait for approval** before changing any code. Nothing is written to disk for this.

## Step 4: Branch
`git fetch origin && git checkout -b hotfix/<ID> origin/<hotfix target branch>`. If it exists, ask: reuse it, or add a suffix.

## Step 5: Fix and verify
1. Spawn the agent triage chose, with the mini-plan in the prompt. It makes the fix, adds or updates the tests, and runs lint plus the tests for the changed area **and** the areas that depend on it (unit, API script, or a Playwright spec for a UI flow).
2. Check the diff yourself: it's small, so no separate reviewer is needed. Is it in scope? Does it follow DRY and the engineering standards (no em-dashes, human comments)? Are there side effects?
3. If anything fails, send it back to the same agent once. If it fails again, escalate to `senior-developer`. If the fix is turning out bigger than triage thought, say so and offer to switch to the full pipeline.
4. Visual check: avoid it. If one is truly needed, ask the user once, with the URL and what to look for.

## Step 6: Ship (no further approval needed)
1. Commit: `<ID>: <imperative summary>`, then `git push -u origin hotfix/<ID>`.
2. Create the MR with the short hotfix sections of `REFS/templates/mr-template.md`, targeting the hotfix target branch. Use `glab mr create ... --remove-source-branch --yes`.
3. hotfix-ticket only: post the hotfix Jira comment from `REFS/templates/jira-comment-template.md`, then transition to `jira.transitions.review` if that transition exists.
4. Tell the user: MR link, what was fixed, tests run, and anything parked.
