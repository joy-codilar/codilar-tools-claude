# MR description template

Full pipelines use all the sections. Hotfix pipelines use only: What and why, Changes, How to test, Checks, Deployment notes. Write like a person on the team would, with no em-dashes and no filler.

```markdown
## <ID>: <title>

Jira: <link, or "none">
Plan: `.claude/plans/<ID>.md` · Summary: `.claude/work/<ID>.md` (full pipelines only; leave this line out when `aiVisibility` is false)

### What and why
<2 to 4 sentences: the problem and how this MR solves it.>

### Changes
- `<path or module>`: <what changed>

### How to test
1. <setup, e.g. `php bin/magento setup:upgrade && php bin/magento cache:flush`>
2. <steps a reviewer or QA can follow>

### Checks
| Check | Result |
|---|---|
| Lint / static analysis | PASS |
| Unit tests | 14/14 passed |
| API / Playwright tests | 6/6 passed |
| Build | PASS |

### Might be affected
- <area worth a quick re-check>

### Deployment notes
- <setup:upgrade, reindex, config values, env vars, or "None">

### Dependencies / follow-ups
- <or "None">
```
