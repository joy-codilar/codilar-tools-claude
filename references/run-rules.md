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
  - **Backend / API:** unit tests, plus test scripts for API endpoints (curl or a small script against `localUrl` or a GraphQL/REST endpoint, asserting status codes and response fields). Magento integration tests only where the project already has them configured.
  - **Frontend:** Playwright specs (`npx playwright test`) that assert behaviour: elements present, text, form flows, cart updates, redirects, no console errors, correct network calls. The Playwright MCP server can be used to discover selectors quickly while writing the specs (it reads the accessibility tree, not screenshots).
  - Build, lint and type checks for everything touched.
- If something truly needs human eyes (a pixel-level layout, an animation, a brand colour), avoid it if a behavioural assertion can cover it. If it can't, **ask the user to check**, with the exact URL, viewport and what to look for. Batch these requests into one question just before shipping.
