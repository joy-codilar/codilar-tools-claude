---
name: setup-project
description: "One-time setup of a project repo for the codilar pipelines. Detects the stack, asks for the MR target branches and other project facts, writes .claude/delivery.json, merges the recommended permissions and installs the tooling the pipelines rely on (graphify, Playwright) with the user's OK, and checks glab and Jira. Use when the user runs /codilar:setup-project, or when a pipeline finds no .claude/delivery.json or a missing field."
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
  - add `@playwright/test` as a dev dependency and a `playwright.config.ts` with `baseURL` = localUrl
  - add `tests/e2e/smoke.spec.ts` (the home page or main route loads with no console errors) for projects with a storefront or UI, and `tests/api/health.spec.ts` (one endpoint answers with the expected status, using Playwright's `request` fixture) for projects with an API
  - run `npx playwright install chromium`, then run the new specs once to prove the harness works
  - commit it on its own `task/setup-playwright` branch, not on the developer's current branch, and offer to push it and open the MR

  React Native apps: Playwright can't drive native screens, so the harness only covers the backend API the app calls. Native flows stay with Detox or Maestro.

If the user declines either tool, record nothing and carry on. The pipelines ask about graphify again at the start of a run and fall back to normal search, and QA falls back to test scripts and marks Playwright as NOT RUN in its report and the MR.

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
  "notes": "Project-specific things the agents should know: conventions, areas not to touch, client quirks."
}
```
`{paths}` is replaced with the changed files or modules at run time. Get `gitlab.project` from `git remote get-url origin`. Show the file to the user before writing it.

## 5. Permissions and folders
- Merge `${CLAUDE_SKILL_DIR}/../../settings/project-settings.json` into the project's `.claude/settings.json`: union the `allow`/`deny` arrays and keep the existing entries. Show the diff and ask before writing.
- Create `.claude/plans/` and `.claude/work/` (each with a `.gitkeep`). They're committed: the full pipelines save a plan and a summary per task there.

## 6. Preflight checks (report PASS / FAIL for each, with the fix)
- `glab auth status --hostname gitlab.codilar.in`. Fix: `glab auth login --hostname gitlab.codilar.in`.
- Jira MCP: fetch any issue in the project key. Fix: `/mcp` and authenticate `atlassian`.
- Playwright: `npx playwright --version`, the new specs passing, and whether `localUrl` answers (`curl -sI`).
- Code index: `command -v graphify` and whether `graphify-out/graph.json` exists (INFO, not FAIL, if the user skipped it in step 2b).
- Working tree state (`git status --porcelain`), just reported.

Finish with one line listing the four commands: `/codilar:deliver-ticket <KEY>`, `/codilar:deliver`, `/codilar:hotfix-ticket <KEY>`, `/codilar:hotfix`.
