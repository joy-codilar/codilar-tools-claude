---
name: setup-project
description: "One-time setup of a project repo for the codilar pipelines. Detects the stack, asks for the MR target branches and other project facts, writes .claude/delivery.json, merges the recommended permissions and checks the tooling (glab, Jira, Playwright). Use when the user runs /codilar:setup-project, or when a pipeline finds no .claude/delivery.json or a missing field."
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
4. **Jira project key(s)** and the **local URL** for tests (Valet default: `https://<folder-name>.test`; skip for pure API repos). Combine these into one question with an "Other" free-text answer if that's easier.

If Playwright isn't in `testTools` and the project has a storefront or UI, ask one more question: **add a minimal Playwright harness?** It adds `@playwright/test` as a dev dependency, a `playwright.config.ts` with `baseURL` = localUrl, and a `tests/e2e/` folder with one smoke spec, then runs `npx playwright install chromium`. It goes in its own commit on a `task/setup-playwright` branch, not on the developer's current branch. The recommended answer is yes, because agents use it instead of visual QA.

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
- Playwright: `npx playwright --version`, and whether `localUrl` answers (`curl -sI`).
- Code index: `command -v graphify` and whether `graphify-out/graph.json` exists. Report only (INFO, not FAIL). The pipelines offer to install it and build the graph on their first run (run rules section 6).
- Working tree state (`git status --porcelain`), just reported.

Finish with one line listing the four commands: `/codilar:deliver-ticket <KEY>`, `/codilar:deliver`, `/codilar:hotfix-ticket <KEY>`, `/codilar:hotfix`.
