# Full pipeline (deliver and deliver-ticket)

`REFS` below means the `references/` folder of this plugin. The skill that sent you here gives you its absolute path. `<ID>` is the Jira key, or a short kebab-case name for `deliver`.

Records (both committed with the MR):
- `.claude/plans/<ID>.md`, built from `REFS/templates/plan-template.md`. It's the single source of truth for the ask, context, Q&A, plan, refinements and parked items. Agents read and write this file instead of scratch files.
- `.claude/work/<ID>.md`, built from `REFS/templates/work-summary-template.md` when the task is done.

Follow `REFS/run-rules.md` for the whole run: keep running, use subagents, handle live refinements, model policy, testing policy.

---

## Phase 0: Preflight
1. If `.claude/delivery.json` is missing, or `targetBranch` is not set, run the `codilar:setup-project` skill first. It asks for the target branch. Never assume one.
2. Uncommitted changes in the working tree: ask whether to stash them, commit them first, or abort.
3. GitLab access: check the GitLab MCP tools and `glab auth status --hostname <gitlab.host>` (run rules section 8). If either fails, tell the user now what to do, using the table there. Ticket pipeline only: check the Jira MCP tools respond, and if not, tell the user to run `/mcp` and authenticate `atlassian`.
4. If `.claude/plans/<ID>.md` already exists, ask: resume from it, or start over.
5. Code index: set up graphify as described in run rules section 6 (refresh, build, or ask once to install). Finish this before Phase 1, because the analyst explores the code.
6. Playwright: if the project has no Playwright harness, add it now (run rules section 5). Ask in the same AskUserQuestion call as the graphify question when both are missing.

## Phase 1: Understand
- **deliver-ticket:** spawn `ticket-analyst` (sonnet). It reads the issue, comments, subtasks, parent/epic, linked and sibling issues, attachments and Confluence links, plus earlier commits and MRs for related keys. It explores the affected code and writes the first sections of `.claude/plans/<ID>.md`: The ask, Context, Acceptance criteria, Questions (ambiguities), plus a size rating.
- **deliver:** the intake happens in the skill: you have the user's requirement. Spawn `ticket-analyst` in *no-ticket mode* with the requirement text. It skips Jira and does the codebase exploration and the same plan sections.

**Size check (rule: suggest a smaller pipeline):** if the analyst rates the task **S** (one area, a few files, no schema or contract changes), ask the user whether to switch to `codilar:hotfix` / `codilar:hotfix-ticket` or continue with the full pipeline. If they switch, hand over the context you already have and follow `REFS/hotfix-pipeline.md` from its triage step.

## Phase 2: Architect review and draft plan
Spawn `solution-architect` (opus) with the plan file path. It:
- **challenges the ask** where there's a better, simpler or safer way, and adds that as a question with its recommendation
- designs the approach and work units (each routed to an agent, see the routing table below), the reuse (DRY) list, the impact analysis and the test plan
- adds questions for anything it needs decided, **including any logic it thinks must be duplicated** (DRY exception, which needs the user's OK)

## Phase 3: Questionnaire
Put all open questions from the analyst and the architect to the user in one go (AskUserQuestion: up to 4 per call, concrete options, recommended option first; use several calls if needed). Show the non-blocking defaults as a short list the user can override. Record every question and answer in the plan's "Questions and answers" table.

## Phase 4: Plan approval (hard gate)
- If the answers change the approach, send them back to `solution-architect` to update the plan.
- Set Status to AWAITING APPROVAL. Show the user a readable summary of the plan (approach, units and agents, reuse, impact, test plan, risks) and the path to the full file.
- **Don't write any code until the user explicitly approves.** Handle change requests by updating the plan and showing it again.
- When approved: set Status to APPROVED. Ticket pipeline: transition the issue to `jira.transitions.start` if that transition exists.

## Phase 5: Branch
- Branch type: deliver-ticket uses the Jira issue type (`branchPrefixes.feature` gives `feature/<ID>`, anything else gives `task/<ID>`). deliver uses the type the architect proposed and the user confirmed in the questionnaire.
- `git fetch origin && git checkout -b <branch> origin/<targetBranch>`. If the branch exists, ask: reuse it, or create a fresh one with a suffix.

## Phase 6: Implement
Routing table:

| Work touches | Agent |
|---|---|
| Magento modules: PHP, di.xml, db_schema, plugins, observers, GraphQL/REST, cron, admin | `magento-backend-developer` |
| Luma/Blank-based theme: layout XML, phtml, LESS, RequireJS, KnockoutJS | `luma-frontend-developer` |
| Hyva theme or compat modules: phtml with Alpine.js, Tailwind, ViewModels | `hyva-frontend-developer` |
| Shopify theme, app or Hydrogen | `shopify-developer` |
| Akinon ProjectZero storefront or extension | `akinon-developer` |
| Next.js app | `nextjs-developer` |
| React Native app | `react-native-developer` |
| NestJS API | `nestjs-developer` |
| L/XL units, security, checkout/payment core, cross-cutting refactors, anything that failed testing twice | `senior-developer` (opus) |
| Purely mechanical S units (translations, config values, copy, renames) | `chore-developer` (haiku) |

Headless projects: if a unit needs a backend change whose code isn't in this repo, don't implement it. Record it as an external dependency and tell the user.

Spawn units that have no dependencies and no shared files in one message, in the background, so they run in parallel. Run dependent units in order. Give each agent the plan path, its unit id and the relevant `commands` and `notes` from `delivery.json`. Set plan Status to IN PROGRESS.

## Phase 7: Test and review
1. `qa-engineer` (sonnet): fills gaps in the automated tests, always writes and runs Playwright specs for the acceptance criteria and the impacted areas, runs lint/static/unit/build (see the testing policy in the run rules) and returns a results table plus any **visual checks it couldn't automate**.
2. Failures go back to the owning agent, and after the second failure on the same unit, to `senior-developer`. Re-test. Keep iterating (run rules, section 1).
3. `code-reviewer` (opus) can start reading the diff while the final QA round runs. It checks the acceptance criteria, the engineering standards (DRY, impact on other areas, human tone), security and performance. Blocking findings go through the fix and re-test loop.
4. Visual checks: if any remain, ask the user in one batched question (URL, viewport, what to look for). Fix anything they report.

## Phase 8: Ship (no further approval needed)
1. Commit the code in logical chunks: `<ID>: <imperative summary>`, with a body saying why. Never commit secrets, `env.php`, `auth.json` or `.env*`.
2. `git push -u origin <branch>`
3. `release-reporter` (haiku) writes the MR description from `REFS/templates/mr-template.md`. Then create the MR (run rules section 8): with the GitLab MCP tools if they respond (source `<branch>`, target `<targetBranch>`, title `<ID>: <title>`, remove the source branch on merge), otherwise with `glab`:
   `glab mr create --source-branch <branch> --target-branch <targetBranch> --title "<ID>: <title>" --description "<text>" --remove-source-branch --yes`
   Pass the text however is safest in the shell (a heredoc into a variable works). Mark it as a draft if external dependencies remain. If both fail, follow the fallback in run rules section 8 and guide the user.
4. `release-reporter` writes `.claude/work/<ID>.md` from `REFS/templates/work-summary-template.md`, including the MR URL and the code commit SHAs. Set plan Status to DONE.
5. Commit both records: `<ID>: add plan and delivery summary`, then push. The MR picks it up. **Skip this step when `aiVisibility` is `false`**: the records stay local (run rules section 7).
6. deliver-ticket only: post the Jira comment (`REFS/templates/jira-comment-template.md`, full pipeline section) with the Jira MCP, then transition to `jira.transitions.review` if that transition exists.

## Phase 9: Wrap up
In a few lines, tell the user: the MR link, the branch, the test results, anything parked or still a dependency, and the path to the summary file.
