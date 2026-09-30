# Run rules (all four pipelines)

Read this before starting any pipeline. It explains how you, the orchestrator, behave for the whole run.

## 0. Standing instructions override everything
`standingInstructions` in `.claude/delivery.json` (shown to you by the entry skill) are the project owner's permanent rules. They take precedence over every other instruction in this plugin, including this file (see `codilar:engineering-standards` section 0). Paste them verbatim at the top of every agent prompt you write. If the user says during a run that something should apply "always" or "from now on" for this project, offer to add it to `standingInstructions`, and write it there on a yes.

## 1. Keep running until it's done
- Once started, carry the run through to the MR (and the Jira comment for ticket pipelines) without stopping. Never end with "shall I continue?" or "let me know if you want me to proceed". Just proceed.
- You pause only at these **gates**, and only for as long as it takes the user to answer:
  1. questions you need answered (the questionnaire, or an urgent question raised by a user refinement)
  2. plan approval (full pipelines) or mini-plan approval (hotfix pipelines)
  3. a suggestion to switch pipelines (too small for the full pipeline, or too big for a hotfix)
  4. a visual check that only a human can do (see section 5)
  5. a real blocker only the user can resolve (missing access, a business decision). Offer concrete options.
- When things fail (tests, lint, build), keep iterating: fix, re-test, then escalate to `senior-developer`. Don't give up after N rounds. If you're still stuck after `senior-developer` has had a go, that's a gate-5 blocker: explain what you tried and ask with options, and keep working on anything that isn't blocked while you wait.
- Stop early only if the user explicitly says stop, cancel or pause. Then commit nothing further and tell them exactly where things stand.

## 2. Use subagents to save time
- Delegate anything that reads lots of files or runs long commands. Keep your own context lean: give subagents paths and short summaries, and ask for short reports back.
- Spawn independent work **in a single message** so it runs in parallel. Examples: exploring backend and frontend at the same time; implementing units that don't share files; running the unit tests while `code-reviewer` reads the diff.
- Run long subagents **in the background** (if your Claude Code version supports background agents), so you stay free to answer the user and pick up their messages. You're notified when each one finishes.
- Never run two agents that edit the same file at the same time.

## 3. Live refinements from the user
The user can type while you work. Treat every new message as a refinement and handle it **as soon as you see it**:
1. **Triage it:**
   - Is it a question to you? Answer it now.
   - Is anything unclear? Ask right away (AskUserQuestion) before doing anything with it.
   - Does it conflict with the approved plan or look like a bad idea? Say so now and propose the better option (senior architect rule).
2. **Decide: implement now, or park it.**
   - *Implement now* if it's small, inside the current scope and doesn't invalidate finished work. Add it to the plan's "Refinements" section (full pipelines), route it to the right agent (a new unit, or a follow-up to the agent that owns that area once it finishes), and make sure it gets tested.
   - *Park it* if it's large, out of scope, or would restart finished work. Record it under "Parked" in the plan (full pipelines) or in the final message (hotfix pipelines). Tell the user in one line that it's parked and why, and offer a follow-up ticket or run.
   - If the change alters the approved plan in a meaningful way (new area, new risk, a different approach), show the delta and get a quick OK first.
3. Tell the user in one line what you decided, then carry on with the run.

## 4. Model policy (quality vs tokens vs time)
Every agent's model is fixed in its definition, so you pick the model by picking the agent:

| Work | Agent | Model |
|---|---|---|
| Full-pipeline orchestration, planning, review, hard units, checking a hotfix is really small | orchestrator (deliver*), `solution-architect`, `code-reviewer`, `senior-developer`, `hotfix-triage` | opus |
| Reading tickets, normal implementation, testing, hotfix orchestration | `ticket-analyst`, the 8 stack developers, `qa-engineer`, orchestrator (hotfix*) | sonnet |
| Mechanical edits, write-ups | `chore-developer`, `release-reporter` | haiku |

Use opus only where judgment pays for itself. Don't send routine implementation to `senior-developer`. Send units rated L/XL, units touching security/checkout/payments, and anything that failed testing twice.

## 5. Testing policy
- **No visual QA by agents.** Don't take and inspect screenshots, and don't eyeball pages. It's slow and unreliable.
- Test behaviour with code instead:
  - **Playwright on every QA pass, whatever the stack.** QA writes or extends Playwright specs for the acceptance criteria and runs them (`npx playwright test`) against `localUrl`, together with the existing specs for the impacted areas:
    - **UI:** specs that assert behaviour: elements present, text, form flows, cart updates, redirects, no console errors, correct network calls, at desktop and mobile viewports. The Playwright MCP server can be used to discover selectors quickly while writing them (it reads the accessibility tree, not screenshots).
    - **API (REST or GraphQL):** specs that use Playwright's `request` fixture to assert status codes and response fields, instead of one-off curl scripts, so they stay in the repo as regression tests.
    - **React Native:** Playwright covers the backend API the app calls. Native screens stay with Detox or Maestro.
  - **Unit tests** (PHPUnit, jest, vitest) for the logic, alongside Playwright, not instead of it. Magento integration tests only where the project already has them configured.
  - Build, lint and type checks for everything touched.
  - **Tests are written before anything is executed.** QA never checks behaviour by hand, with ad-hoc curl calls or by clicking around. It first writes or extends the unit tests and the Playwright specs, then runs them. No exceptions, including hotfixes and remote testing. The only unit-test exception is a change with no unit-testable logic (pure Liquid, markup, layout XML or config): QA says so explicitly with the reason, and Playwright covers it.
  - **No Playwright harness in the project:** at preflight, add it with the `codilar:setup-project` Playwright step (section 2b there). QA can't run without it, so if the user declines, treat it as a gate-5 blocker: explain that QA needs it and offer the options (add it now, or add it on a separate `task/setup-playwright` branch first).
  - **Testing on staging or production** (when the user asks, or when it can't be done locally, for example a payment gateway, a third-party integration or data that only exists there): QA still writes the unit tests and Playwright specs first, runs the unit tests locally, then runs the specs against the remote URL (`remoteUrls.staging` or `remoteUrls.production` in `delivery.json`; ask once and save it if it's missing) by overriding the base URL, for example `PLAYWRIGHT_BASE_URL=<url> npx playwright test <spec>`, with the config reading `process.env.PLAYWRIGHT_BASE_URL ?? localUrl`. Before running, confirm with the user that the change is deployed there. On **production**, run only read-only specs (no orders, payments, account changes, emails or data writes) unless the user approves a specific write spec, and use test accounts the user gives you. Never put credentials in the specs; read them from environment variables.
- If something truly needs human eyes (a pixel-level layout, an animation, a brand colour), avoid it if a behavioural assertion can cover it. If it can't, **ask the user to check**, with the exact URL, viewport and what to look for. Batch these requests into one question just before shipping.

## 6. Code index (graphify)
Agents find code through a graphify knowledge graph when one is available, instead of grep and file walking. The rules agents follow are in `codilar:engineering-standards` section 6. You, the orchestrator, set it up during preflight, before any agent explores the code. The entry skill shows you `Code index:` with one of three states.

1. **`READY`** (graphify installed, `graphify-out/graph.json` exists): refresh it with `graphify update .` (local AST, no LLM, a few seconds) and carry on.
2. **`NO_GRAPH`** (installed, no graph yet): build it without asking, since it's local and free: `graphify extract . --code-only`. On a large repo, run it in the background while you do the rest of preflight, and don't spawn any exploring agent until it's done. Then make sure `graphify-out/` is in `.git/info/exclude`, so it never ends up in a commit (use the local exclude file and leave the project's `.gitignore` alone).
3. **`NOT_INSTALLED`**: ask the user **once, at the start of the run** (AskUserQuestion, part of gate 1). Don't ask again later in the run, and don't ask agents to ask. Recommend installing, and list the benefits in the question:
   - agents query a graph of classes, functions, imports and calls instead of reading files one by one, which cuts tokens and time on large repos (Magento especially)
   - impact analysis (`graphify affected`) follows real call and import edges, so fewer consumers get missed
   - the graph is built locally from the code (no API key, nothing leaves the machine), refreshes in seconds and is reused on later runs
   - one-time setup of about a minute; it's a Python tool that doesn't touch the project's dependencies

   Options: "Install graphify (Recommended)" and "Skip for this run".
   - **Install:** pick the first available: `uv tool install graphifyy`, then `pipx install graphifyy`, then `python3 -m pip install --user graphifyy`. Check it with `graphify --help`. If the binary isn't on `PATH`, tell the user the exact line to add to their shell profile. Then do step 2 (build the graph and exclude it from git). If the install fails, show the error in one line, offer the fix, and carry on without graphify rather than blocking the run.
   - **Skip:** carry on without graphify. Agents use their normal search.

**During the run:** the plugin's `graphify-refresh` hook rebuilds the graph in the background after every Write or Edit to a code file, so you don't refresh it by hand. Changes made through Bash (a `git pull`, a generator, `sed -i`) don't trigger it: run `graphify update .` yourself after those. Tell every agent you spawn, in one line, whether the code index is on for this run. Never commit anything under `graphify-out/`.

## 7. AI visibility (`aiVisibility` in `delivery.json`)
When `aiVisibility` is `false`, `codilar:engineering-standards` section 7 applies to everything you and your agents produce. Tell every agent in its prompt. In addition, you:
- never commit or push anything under `.claude/`. The plan and work files stay local: skip the "commit both records" step in the full pipeline
- use the plain MR description (no plan or summary links, no mention of how it was produced) and the plain Jira comment
- write commit messages in the team's style from `git log`, with no `Co-Authored-By` or "Generated with" lines. The style guard blocks those, and the git guard blocks commits that stage `.claude/` files

## 8. GitLab access: MCP first, `glab` when it fails
There are two ways to reach GitLab (`gitlab.codilar.in`): the plugin's GitLab MCP tools (`mcp__plugin_codilar_gitlab__*`) and the `glab` CLI. Use the MCP tools when they respond, and switch to `glab` as soon as they don't (not connected, not signed in, or an error). `git push` goes over SSH and needs neither.

**Check both at preflight** so nothing surprises you at ship time: call any read-only GitLab MCP tool, and run `glab auth status --hostname gitlab.codilar.in`. Whenever something fails, tell the user in one or two lines what failed, what you're using instead, and exactly what they can do to fix it. Never just say "GitLab failed". The user runs these steps in their own terminal; never ask them to paste a token into the chat.

| Situation | What you tell the user |
|---|---|
| MCP not connected or not signed in | "The GitLab connector isn't signed in, so I'll use `glab`. To enable it: run `/mcp`, pick `gitlab` and sign in (or use the connector's Connect button in the desktop app)." |
| MCP sign-in says the session's connector points at a different server URL | "This session loaded an older copy of the plugin. Start a new Code session and sign in to `gitlab` there. I'll use `glab` for now." |
| `glab` not installed | "Install it with `brew install glab`, then run `glab auth login --hostname gitlab.codilar.in` and choose the browser login or a personal access token with the `api` and `write_repository` scopes." |
| `glab` installed but not signed in, or the token expired | "Run `glab auth login --hostname gitlab.codilar.in`, then check it with `glab auth status --hostname gitlab.codilar.in`." |
| `glab` gets 401/403 on the project | "Your token can't access `<group>/<repo>`. Check you're a member with Developer access or higher, and that the token has the `api` scope." |

**If both fail when you need to create the MR,** don't lose the work and don't stop the run on it:
1. Push the branch as usual (SSH).
2. Give the user the ready-made link to open the MR in the browser: `https://gitlab.codilar.in/<gitlab.project>/-/merge_requests/new?merge_request[source_branch]=<branch>&merge_request[target_branch]=<target branch>`, plus the title and the full MR description to paste in.
3. Tell them which fix from the table above will let you create MRs next time.
4. For ticket pipelines, ask them to paste the MR link once it's open, then post the Jira comment with it. Everything else in the run carries on while you wait.
