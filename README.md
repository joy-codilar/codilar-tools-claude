# codilar: delivery pipelines for Claude Code

A Claude Code plugin with four pipelines that take a task from requirement to GitLab MR, using agents that know Codilar's stacks.

| Command | Use it for | What happens |
|---|---|---|
| `/codilar:deliver-ticket ABC-123` | Normal Jira work | Full pipeline: reads the ticket and everything related, asks questions, plans, **waits for your approval**, builds in parallel, tests, reviews, pushes `feature/ABC-123` or `task/ABC-123`, opens an MR, comments on Jira |
| `/codilar:deliver [requirement]` | Work without a ticket | Same full pipeline. It asks you for the requirement first |
| `/codilar:hotfix-ticket ABC-124` | Small Jira fixes | Quick path: opus checks it's really small and shapes the fix, sonnet (or haiku) does it, then it verifies, pushes `hotfix/ABC-124`, opens an MR and comments on Jira |
| `/codilar:hotfix [problem]` | Small fixes without a ticket | Same quick path, and it asks you for the problem first |
| `/codilar:setup-project` | Once per repo | Detects the stack, asks for the target branches, writes `.claude/delivery.json`, adds permissions, checks the tooling |

If you start a full pipeline on something tiny, it suggests switching to a hotfix. If a hotfix turns out bigger than expected, it suggests the full pipeline.

## How a run behaves
- **It keeps going until the MR is up.** It pauses only to ask questions, to get plan approval, to suggest switching pipelines, for a visual check only a human can do, or for a real blocker. It stops early only if you tell it to.
- **Parallel subagents.** Independent work (exploration, implementation units, tests and review) runs at the same time.
- **Live refinements.** Type while it's working. Each message is picked up straight away. If it needs clarifying, you get a question immediately. Otherwise the orchestrator decides whether to implement it now or park it, and tells you which.
- **No visual QA by agents.** Behaviour is tested with unit tests, API test scripts and Playwright specs. If something genuinely needs human eyes, you get one batched request with the URL and what to look for.

## Records (full pipelines only, committed with the MR)
- `.claude/plans/<ID>.md`: the ask, context, acceptance criteria, every question and answer, the approach, work units, reuse (DRY), impact analysis, test plan, refinements and parked items. Nothing gets built until you approve this plan.
- `.claude/work/<ID>.md`: the summary when it's done. It covers the ask, the plan, the questions asked, your answers, the files changed, the branch and commit IDs, how it was tested, how to check the acceptance criteria, and other areas worth re-checking.

`<ID>` is the Jira key, or a short name like `pdp-stock-badge` when there's no ticket. The hotfix pipelines don't write these files; their record is the MR description and the Jira comment.

## Engineering standards (enforced in every pipeline)
From the `engineering-standards` skill, which every agent preloads:
1. Think like a senior architect first, and challenge the ask when there's a better way.
2. Never break another area: find every usage before changing shared code, and test the dependent areas too.
3. Human tone everywhere: no em-dashes, no AI filler, comments that explain why. A hook blocks new em-dashes in files, commits, MRs and Jira comments.
4. DRY: reuse existing code. Any duplication has to be approved by you in the questionnaire.
5. No code before plan approval (mini-plan approval for hotfixes).

## Models

| Model | Used for |
|---|---|
| Opus | deliver orchestrators, `solution-architect`, `code-reviewer`, `senior-developer` (hard units, or ones that failed testing twice), `hotfix-triage` |
| Sonnet | `ticket-analyst`, the 8 stack developers, `qa-engineer`, hotfix orchestrators |
| Haiku | `chore-developer` (mechanical edits), `release-reporter` (write-ups) |

## Supported project types
Magento / Adobe Commerce, Magento + Luma, Magento + Hyva, Shopify (theme, app, Hydrogen), Akinon, Next.js on Magento/Shopify/Akinon, React Native on Magento/Shopify/Akinon, and NestJS + Next.js custom builds. The stack is auto-detected by `skills/setup-project/scripts/detect-stack.sh` and confirmed with you once.

## Install

1. **Prerequisites** (each developer, once):
   ```bash
   brew install glab
   glab auth login --hostname gitlab.codilar.in
   ```
2. **MCP config** (in this folder): make sure `.mcp.json` matches `mcp.json.example` (Atlassian, GitLab and Playwright servers). If you haven't created it yet: `cp mcp.json.example .mcp.json`.
3. **Try it locally:**
   ```bash
   cd ~/Projects/vanillam2
   claude --plugin-dir ~/Projects/playground/claude-agents
   ```
   Then run `/mcp` and authenticate `atlassian`.
4. **Share it:** push this folder to GitLab (e.g. `gitlab.codilar.in/tools/claude-agents`). Each developer then runs:
   ```
   /plugin marketplace add https://gitlab.codilar.in/tools/claude-agents.git
   /plugin install codilar@codilar-tools
   ```
   To ship updates, bump `version` in `.claude-plugin/plugin.json` and push.
5. **Per repo:** run `/codilar:setup-project`, then commit `.claude/delivery.json`, `.claude/settings.json`, `.claude/plans/` and `.claude/work/`.

## Layout
```
.claude-plugin/          plugin.json, marketplace.json
mcp.json.example         Atlassian, GitLab, Playwright MCP servers (copy to .mcp.json)
hooks/hooks.json         runs the two guards before tool calls
scripts/guard-git.sh     blocks pushes/commits to protected branches, force pushes, destructive commands
scripts/style-guard.*    blocks new em-dashes in files, commits, MRs and Jira comments
settings/                permissions merged into each project by setup-project
references/              run-rules.md, full-pipeline.md, hotfix-pipeline.md, templates/ (plan, work summary, MR, Jira)
skills/                  deliver, deliver-ticket, hotfix, hotfix-ticket, setup-project, engineering-standards,
                         plus stack knowledge: magento-backend, magento-luma, magento-hyva, shopify, akinon,
                         nextjs, react-native, nestjs, headless-backends
agents/                  16 agents (see the model table)
```

## Troubleshooting
- **Jira tools missing:** run `/mcp` and re-authenticate `atlassian`. If OAuth fails, change the URL to `https://mcp.atlassian.com/v1/mcp/authv2`.
- **GitLab MCP won't connect:** that's fine, MRs are created with `glab`. The env var `CODILAR_GITLAB_URL` overrides the host.
- **Permission prompts for plugin MCP tools:** run `/permissions` to see the real tool names (`mcp__plugin_<plugin>_<server>__<tool>`) and adjust `settings/project-settings.json`.
- **An agent ignores stack rules:** check that its `skills:` preload resolves. If the namespaced names (`codilar:magento-backend`) don't work in your Claude Code version, use the bare names.
- **The style guard blocks an edit to a file that already had em-dashes:** it only blocks *new* ones, so rewrite the new text without them.
