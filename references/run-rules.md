# Run rules (all four pipelines)

Read this before starting any pipeline. It explains how you, the orchestrator, behave for the whole run.

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
  - **No Playwright harness in the project:** at preflight, offer to add it with the `codilar:setup-project` Playwright step (section 2b there). If the user declines, QA falls back to curl or small scripts and reports Playwright as NOT RUN, and the MR says so.
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
