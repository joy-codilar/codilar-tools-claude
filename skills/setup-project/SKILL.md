---
name: setup-project
description: "One-time setup of a project repo for the codilar pipelines. Detects the stack, asks for the MR target branches and other project facts, writes .claude/delivery.json, records standing instructions and whether AI involvement should be visible, merges the recommended permissions and installs the tooling the pipelines rely on (graphify, Playwright) with the user's OK, and checks GitLab (MCP or glab) and Jira. Use when the user runs /codilar:setup-project, or when a pipeline finds no .claude/delivery.json or a missing field."
argument-hint: "[--reconfigure]"
---

# Set up this repo for the codilar pipelines

Goal: produce `.claude/delivery.json` in the project root (committed, so the whole team shares it) and make sure the tooling works. Ask for anything you can't detect. **Never guess a target branch.** Write like a human, with no em-dashes.

## 1. Detect the stack
```bash
bash "${CLAUDE_SKILL_DIR}/scripts/detect-stack.sh" "$CLAUDE_PROJECT_DIR"
```
This prints JSON with `suggestedProfile`, `components` (type, path, backend, themes, edition), `testTools` and git info. The profiles:

| Profile | Project type |
|---|---|
| `magento` | Magento / Adobe Commerce (backend-focused, stock storefront) |
| `magento-luma` | Magento backend + Luma-based theme |
| `magento-hyva` | Magento backend + Hyva theme |
| `shopify` | Shopify theme / app / Hydrogen |
| `akinon` | Akinon (ProjectZero storefront or backend extension) |
| `nextjs-magento` / `nextjs-shopify` / `nextjs-akinon` | Next.js headless storefront on that backend |
| `react-native-magento` / `react-native-shopify` / `react-native-akinon` | React Native app on that backend |
| `custom-nestjs-nextjs` | Custom build: NestJS API + Next.js frontend |

If the backend is `unknown`, or several types match, ask.

## 2. Ask the user (AskUserQuestion, up to 4 questions per call)
1. **Confirm the profile.** The detected one is the recommended option.
2. **MR target branch** for deliver pipelines. Required. Offer the candidates from `git branch -r` (develop, main, staging...). Skip this if it's already set and this isn't `--reconfigure`.
3. **Hotfix target branch.** Offer "same as above" first, then the other candidates (e.g. main or production).
4. **Jira project key(s)** and the **local URL** for tests (Valet default: `https://<folder-name>.test`; for a pure API repo, the local API base URL). Combine these into one question with an "Other" free-text answer if that's easier.

## 2b. Tooling: graphify and Playwright
Check both, then ask about whichever is missing in **one** AskUserQuestion call (one question each, "Install (Recommended)" first). Skip a question when the tool is already in place.

- **graphify** (missing when `command -v graphify` fails). List the benefits and install it exactly as described in `${CLAUDE_SKILL_DIR}/../../references/run-rules.md` section 6 (the `NOT_INSTALLED` case), then build the graph and exclude `graphify-out/` from git (the `NO_GRAPH` case). If graphify is installed but there's no graph yet, build it without asking.
- **Playwright** (missing when `@playwright/test` isn't in any `package.json` or there's no `playwright.config.*`). QA runs Playwright on every pass (run rules section 5), so recommend it for every profile. Benefits to list: QA proves behaviour with committed specs instead of anyone eyeballing pages, the same runner covers UI flows and API endpoints, and the specs stay in the repo as regression tests. On yes:
  - add `@playwright/test` as a dev dependency and a `playwright.config.ts` with `baseURL: process.env.PLAYWRIGHT_BASE_URL ?? '<localUrl>'`, so the same specs can run against staging or production
  - add `tests/e2e/smoke.spec.ts` (the home page or main route loads with no console errors) for projects with a storefront or UI, and `tests/api/health.spec.ts` (one endpoint answers with the expected status, using Playwright's `request` fixture) for projects with an API
  - run `npx playwright install chromium`, then run the new specs once to prove the harness works
  - commit it on its own `task/setup-playwright` branch, not on the developer's current branch, and offer to push it and open the MR

  React Native apps: Playwright can't drive native screens, so the harness only covers the backend API the app calls. Native flows stay with Detox or Maestro.

If the user declines graphify, carry on: the pipelines ask again at the start of a run and fall back to normal search. Playwright is required for QA (run rules section 5). If the user declines it, explain that QA can't run without it and that the pipelines will ask again before QA.

## 2c. Project rules: standing instructions and AI visibility
Ask both in one AskUserQuestion call (skip a question if it's already answered and this isn't `--reconfigure`).

1. **"Are there any standing instructions you want me to remember for this project?"** Options: "None for now" and the free-text "Other". Whatever the user types is saved word for word in `standingInstructions` (an array; one entry per instruction if they list several). Tell them in one line that these override every other instruction in the plugin when they conflict, and that they can add more later by re-running setup or by saying "always ..." during a run.
2. **"Should the repo show that AI is working on it?"**
   - **"Yes, that's fine"**: `"aiVisibility": true`. Normal behaviour: `.claude/` is committed and plan and work records go in with each MR.
   - **"No, keep it looking hand-written"**: `"aiVisibility": false`. Then:
     - add `.claude/` to `.git/info/exclude` so it's never committed (the local exclude file keeps the project's `.gitignore` free of any hint). If `.claude/` is already tracked, tell the user, and offer to untrack it (`git rm -r --cached .claude`) in its own commit on a `task/` branch
     - in the local `.claude/settings.json`, set `"includeCoAuthoredBy": false` and `"attribution": { "commit": "", "pr": "" }`, so Claude Code adds no attribution to commits or MRs
     - skip creating `.gitkeep` files in `.claude/plans/` and `.claude/work/` (the folders are local anyway)
     - every pipeline then follows `codilar:engineering-standards` section 7: no emojis, no em-dashes, short human comments, no mention of AI anywhere
   Because `.claude/delivery.json` stays local in this mode, every developer on the project runs setup once on their own machine.

## 3. Work out the commands
Start from these defaults. Keep only commands whose binaries or scripts actually exist (check `vendor/bin` and the `package.json` scripts).

| Profile | lint / static | unit | build / local deploy | e2e |
|---|---|---|---|---|
| magento* | `vendor/bin/phpcs --standard=Magento2 {paths}`, `vendor/bin/phpstan analyse {paths}` | `vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist {paths}` | `php bin/magento setup:upgrade`, `php bin/magento cache:flush` | `npx playwright test` |
| magento-hyva (extra) | | | `npm --prefix app/design/frontend/<Vendor>/<theme>/web/tailwind run build-prod` | |
| magento-luma (extra) | | | `php bin/magento setup:static-content:deploy -f <locales>` (production mode only) | |
| shopify theme | `shopify theme check` | | | `npx playwright test` against the preview URL |
| shopify app / hydrogen | `npm run lint` | `npm test` | `npm run build` | `npx playwright test` |
| akinon / nextjs-* / custom | `npm run lint`, `npx tsc --noEmit` | `npm test` | `npm run build` | `npx playwright test` |
| react-native-* | `npm run lint`, `npx tsc --noEmit` | `npm test` | | Detox/Maestro if present |
| nestjs | `npm run lint` | `npm test` | `npm run build` | `npm run test:e2e` |

Magento runs natively (Valet): call `php bin/magento ...` directly.

## 4. Write `.claude/delivery.json`
```json
{
  "profile": "magento-hyva",
  "components": [ { "type": "magento", "path": ".", "frontend": "hyva", "themes": ["Codilar/child"] } ],
  "targetBranch": "develop",
  "hotfixTargetBranch": "develop",
  "branchPrefixes": {
    "feature": ["Story", "New Feature", "Epic", "Improvement"],
    "task": ["Task", "Sub-task", "Subtask", "Bug"]
  },
  "jira": { "projectKeys": ["ABC"], "transitions": { "start": "In Progress", "review": "Code Review" } },
  "gitlab": { "host": "gitlab.codilar.in", "project": "<group>/<repo>" },
  "localUrl": "https://vanillam2.test",
  "commands": {
    "lint": ["vendor/bin/phpcs --standard=Magento2 {paths}"],
    "unit": ["vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist {paths}"],
    "build": ["php bin/magento setup:upgrade", "php bin/magento cache:flush"],
    "e2e": ["npx playwright test"]
  },
  "notes": "Project-specific things the agents should know: conventions, areas not to touch, client quirks.",
  "standingInstructions": ["Never touch the Codilar_Legacy module.", "All prices are shown including tax."],
  "aiVisibility": true,
  "remoteUrls": { "staging": "https://staging.example.com", "production": "" }
}
```
`{paths}` is replaced with the changed files or modules at run time. `remoteUrls` is optional: fill in what the user knows, and the pipelines ask for it the first time remote testing is needed. Get `gitlab.project` from `git remote get-url origin`. Show the file to the user before writing it.

## 5. Permissions and folders
- Merge `${CLAUDE_SKILL_DIR}/../../settings/project-settings.json` into the project's `.claude/settings.json`: union the `allow`/`deny` arrays and keep the existing entries. Show the diff and ask before writing.
- Create `.claude/plans/` and `.claude/work/`. When `aiVisibility` is true, add a `.gitkeep` to each: they're committed, and the full pipelines save a plan and a summary per task there. When it's false, they stay local (step 2c).

## 6. Preflight checks (report PASS / FAIL for each, with the fix)
- GitLab: the GitLab MCP tools respond, and `glab auth status --hostname gitlab.codilar.in` passes. The pipelines need at least one of them. For each one that fails, give the fix from the table in `${CLAUDE_SKILL_DIR}/../../references/run-rules.md` section 8.
- Jira MCP: fetch any issue in the project key. Fix: `/mcp` and authenticate `atlassian`.
- Playwright: `npx playwright --version`, the new specs passing, and whether `localUrl` answers (`curl -sI`).
- Code index: `command -v graphify` and whether `graphify-out/graph.json` exists (INFO, not FAIL, if the user skipped it in step 2b).
- Working tree state (`git status --porcelain`), just reported.

Finish with one line listing the four commands: `/codilar:deliver-ticket <KEY>`, `/codilar:deliver`, `/codilar:hotfix-ticket <KEY>`, `/codilar:hotfix`.
