# CLAUDE.md: codilar plugin (maintainer guide)

This repository **is** a Claude Code plugin. It is not an application. You maintain prompts, agent definitions, skills, hooks and small shell/Python scripts that Codilar developers install into Claude Code. Read this file fully before changing anything.

Owner: Joy (joy@codilar.com). Repo: `github.com/joy-codilar/codilar-tools-claude` (branch `main`). Plugin name `codilar`, marketplace name `codilar-tools`.

---

## 1. Mind map

```
codilar plugin
├── Purpose: take a task from requirement to a reviewed GitLab MR, the Codilar way
│
├── Entry points (skills users type)
│   ├── /codilar:deliver-ticket <KEY>  ─┐
│   ├── /codilar:deliver [text]        ─┴─> references/full-pipeline.md   (orchestrator on opus)
│   ├── /codilar:hotfix-ticket <KEY>   ─┐
│   ├── /codilar:hotfix [text]         ─┴─> references/hotfix-pipeline.md (orchestrator on sonnet)
│   └── /codilar:setup-project          ──> writes .claude/delivery.json, offers graphify + Playwright
│
├── Shared rules (read by every pipeline first)
│   └── references/run-rules.md
│       ├── keep running until the MR is up; pause only at the 5 gates
│       ├── spawn subagents in parallel and in the background
│       ├── live refinements: triage, ask now, implement or park
│       ├── model policy table
│       ├── testing policy: no visual QA; unit + Playwright on every QA pass (UI and API)
│       └── code index: graphify refresh/build, or ask once to install
│
├── Engineering standards (skill preloaded by every agent)
│   └── skills/engineering-standards: architect-first, no collateral damage, DRY
│       (duplication needs user approval), human tone with no em-dashes, scope discipline,
│       graphify first for finding code and impact (grep only for markup/config)
│
├── Agents (agents/*.md, model fixed per agent)
│   ├── opus:   solution-architect, code-reviewer, senior-developer, hotfix-triage
│   ├── sonnet: ticket-analyst, qa-engineer, 8 stack developers
│   │           magento-backend, luma-frontend, hyva-frontend, shopify, akinon,
│   │           nextjs, react-native, nestjs
│   └── haiku:  chore-developer, release-reporter
│
├── Stack knowledge (skills, user-invocable: false, preloaded via agent `skills:`)
│   magento-backend, magento-luma, magento-hyva, shopify, akinon,
│   nextjs, react-native, nestjs, headless-backends
│
├── Records written in the TARGET project (full pipelines only, committed with the MR)
│   ├── .claude/plans/<ID>.md   (template: references/templates/plan-template.md)
│   └── .claude/work/<ID>.md    (template: references/templates/work-summary-template.md)
│
├── Guardrails
│   ├── hooks/hooks.json -> scripts/guard-git.sh    (protected branches, force push, destructive cmds)
│   ├── hooks/hooks.json -> scripts/style-guard.*   (blocks NEW em-dashes in writes/commits/MR/Jira)
│   ├── hooks/hooks.json -> scripts/graphify-refresh.sh (PostToolUse: background graph update after code edits)
│   └── settings/project-settings.json              (allow/deny list merged by setup-project)
│
├── Integrations (.mcp.json)
│   ├── atlassian  (Jira/Confluence, OAuth via /mcp)
│   ├── gitlab     (self-hosted gitlab.codilar.in, optional; glab CLI is the primary path)
│   └── playwright (selector discovery; committed specs are the real tests)
│
└── Distribution
    ├── marketplace.json source "./" (repo = marketplace + plugin)
    ├── devs install codilar@codilar-tools, with auto-update on
    └── a release = bump version in plugin.json + push to main
```

## 2. How the pieces connect

1. The user runs an entry skill, e.g. `skills/deliver-ticket/SKILL.md`. Entry skills are **thin**. They set `<ID>`, handle intake, inject `.claude/delivery.json` and `git status` with `!` commands, and tell the orchestrator to read `REFS/run-rules.md` plus the right pipeline file. `REFS` = `${CLAUDE_SKILL_DIR}/../../references`.
2. The pipeline file defines the phases and the **routing table** (which agent handles which kind of work).
3. The orchestrator spawns agents by name. Each agent's model is fixed in its frontmatter. **The orchestrator picks the model by picking the agent.** There's no per-spawn model override.
4. Agents preload `codilar:engineering-standards` plus their stack skills via the `skills:` frontmatter.
5. In the full pipelines, agents share state through **one file**, `.claude/plans/<ID>.md` in the target project. There are no scratch files. Hotfix pipelines pass context in prompts only.
6. Shipping uses `glab mr create`. The Jira comment goes through the Atlassian MCP tools. `release-reporter` fills the templates.

## 3. Product requirements (from the owner, keep these true)

Each one maps to where it's implemented:

| Requirement | Where |
|---|---|
| Full pipeline for Jira (`deliver-ticket`) and without Jira (`deliver`, which asks for the requirement) | skills/deliver*, references/full-pipeline.md |
| Hotfix pipelines: opus only to validate it's small, a cheaper model does the work, no plans/work files | skills/hotfix*, references/hotfix-pipeline.md, agents/hotfix-triage.md |
| Suggest hotfix when a full task is tiny; suggest the full pipeline when a hotfix is too big | full-pipeline Phase 1 size check; hotfix-pipeline Step 2 |
| Runs without stopping unless the user says stop (the gates are the only pauses) | run-rules section 1 |
| Spawns subagents as it sees fit, in parallel | run-rules section 2 |
| Mid-run prompts are picked up immediately: ask now, implement now or park | run-rules section 3 |
| Model choice balances quality, tokens and time | run-rules section 4; agent frontmatter |
| No visual QA by agents; QA always uses Playwright (UI specs and `request` specs for APIs) plus unit tests; ask the user when unavoidable | run-rules section 5; qa-engineer |
| Setup offers to install graphify and a Playwright harness when missing | setup-project step 2b; pipeline preflight |
| Architect mindset, challenge the user | engineering-standards section 1; solution-architect; hotfix-triage |
| Never break other areas; holistic impact analysis | engineering-standards section 2; plan "Impact analysis" section; code-reviewer |
| No em-dashes or AI-sounding text | engineering-standards section 4; style-guard hook |
| DRY; duplication only with user approval in the questionnaire | engineering-standards section 3; solution-architect step 6 |
| No work before the user approves the plan; plans in `.claude/plans/*.md` | full-pipeline Phase 4 |
| Summary per task in `.claude/work/*.md` with 9 specific sections | work-summary-template.md; release-reporter |
| Branches: `feature/<ID>` or `task/<ID>`; hotfixes use `hotfix/<ID>` | full-pipeline Phase 5; hotfix-pipeline Step 4 |
| MR target branch declared per project, asked the first time | setup-project step 2; guard reads it |
| Records are committed with the MR | full-pipeline Phase 8 step 5 |
| Magento runs natively (Valet), with no docker wrappers | stack skills, setup-project commands |
| GitLab is self-hosted at gitlab.codilar.in | .mcp.json, setup-project, settings |
| Use graphify for code indexing and retrieval when installed; if not, ask once at the start of the run (with benefits), install on yes, carry on normally on no. Keep the graph current after every change | run-rules section 6; engineering-standards section 6; entry skills (`Code index:` line); pipeline preflight; scripts/graphify-refresh.sh |

## 4. Rules for changing this repo

- **Follow the rules we impose on others.** No em-dashes anywhere (the style guard blocks you too). No AI filler. Plain, professional English.
- **DRY in prompts.** Behaviour shared by several pipelines goes in `references/` (run-rules, pipeline files, templates), never copied into several skills. Entry skills stay thin. Rules for all agents go in `engineering-standards`. Stack facts go in the stack skill, not in agent bodies.
- The 8 stack developer agents share an identical "How you work" block. When you change one, change all 8 the same way.
- **Frontmatter:** quote any `description` that contains a colon (YAML breaks otherwise). Keep `name` identical to the file or folder name. Stack skills keep `user-invocable: false`. Entry skills keep `disable-model-invocation: true`.
- **Adding a stack:** create `skills/<stack>/SKILL.md`, add `agents/<stack>-developer.md` (copy an existing developer agent), extend `skills/setup-project/scripts/detect-stack.sh`, add the profile to the setup-project table and the routing table in `references/full-pipeline.md`, then update the README tables.
- **Adding an agent:** give it `skills: codilar:engineering-standards` at minimum, choose the cheapest model that can do the job well, and add it to the model table in run-rules and the README.
- **Permissions:** plugins can't ship permission settings. They live in `settings/project-settings.json` and are merged into each project by setup-project. Plugin MCP tools are named `mcp__plugin_codilar_<server>__<tool>`.
- **Paths:** skills refer to shared files through `${CLAUDE_SKILL_DIR}/../../...`. Hooks use `${CLAUDE_PLUGIN_ROOT}`.
- **Every release:** bump `version` in `.claude-plugin/plugin.json`, because installed copies only update on a version change. Update the README if user-facing behaviour changed.

## 5. Testing changes

```bash
claude plugin validate .                                   # manifest + marketplace
claude --plugin-dir . ...                                  # load the working copy in a sample project

# git guard: expect exit 2 for protected pushes, 0 for task/feature/hotfix branches
printf '{"tool_input":{"command":"git push origin develop"}}' | bash scripts/guard-git.sh; echo $?

# style guard: expect exit 2 when an Edit adds an em-dash
printf '{"tool_name":"Edit","tool_input":{"old_string":"a","new_string":"b — c"}}' | bash scripts/style-guard.sh; echo $?

# graphify refresh: exits 0 at once; in a project with graphify-out/graph.json it starts a background `graphify update .`
printf '{"tool_input":{"file_path":"%s/a.php"}}' "$PWD" | CLAUDE_PROJECT_DIR="$PWD" bash scripts/graphify-refresh.sh; echo $?

# stack detector against a real repo
bash skills/setup-project/scripts/detect-stack.sh ~/Projects/vanillam2
```

The detector was checked against fixtures for Hyva, Luma/EE, Shopify theme, Akinon, Next.js+Shopify, React Native (Expo)+Magento and a NestJS+Next.js monorepo, and against `~/Projects/vanillam2` (plain Magento 2.4.9 gives profile `magento`). It runs in about 14 seconds on a large Magento repo over a mounted drive, and faster natively.

## 6. Known assumptions to verify in real use

- Agent `skills:` preloading with namespaced names (`codilar:magento-backend`). If they don't resolve, switch to bare names.
- Live refinements depend on Claude Code delivering user messages mid-run, and on background subagents being supported by the installed version.
- The Atlassian MCP URL `https://mcp.atlassian.com/v1/mcp` (fallback: `/v1/mcp/authv2`).
- The GitLab MCP server at `gitlab.codilar.in/api/v4/mcp` needs a GitLab version with the MCP feature enabled. `glab` is the primary path.
- Plugin MCP permission names (`mcp__plugin_codilar_<server>__*`). Confirm with `/permissions`.
- The Akinon skill is deliberately conservative. It should be tightened by an Akinon specialist.
- Managed-settings auto-install behaviour varies by Claude Code version. Devs may need one `/plugin install`.
- graphify: `graphify extract . --code-only` (first build, no API key) plus `affected`, `query` and `update` were checked on a small fixture. Still to check: how long the first build takes on a large Magento repo, and how good the PHP call edges are for DI-heavy code (plugins and preferences are wired in XML, which the graph doesn't index).

## 7. Backlog ideas

- One-time installer script (SSH check, marketplace add, auto-update, glab login) plus a managed-settings file for MDM.
- A `codilar:resume <ID>` entry point that picks up an interrupted full pipeline from its plan file.
- Stack skill for Adobe Commerce Cloud deployments (ece-tools, `.magento.app.yaml`).
- Stack detector: support for pnpm/Nx workspace globs beyond depth 3.
