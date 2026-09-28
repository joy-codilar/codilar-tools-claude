# Jira comment template

Keep it scannable for PMs, QA and the client. Plain language, no code, no em-dashes, no emojis.

## Full pipeline (deliver-ticket)

```markdown
**Development done, ready for code review**

**MR:** <MR URL> (`<branch>` into `<target branch>`)

**What was done**
- <user-facing change>
- <user-facing change>

**Agreed before development**
- <question>: <answer>  (leave this section out if there were no questions)

**Tests run**
| # | Case | Type | Result |
|---|---|---|---|
| 1 | <scenario tied to an acceptance criterion> | Unit / API / Playwright | Pass |

**How QA can verify**
1. <step>
2. <step>

**Worth re-checking:** <areas that might be affected>
**Deployment notes:** <or "None">
**Open items:** <or "None">
```

## Hotfix (hotfix-ticket)

```markdown
**Hotfix ready for review:** <MR URL>

**Cause:** <one or two sentences>
**Fix:** <one or two sentences>
**Tested:** <tests run and results, one line each>
**How to verify:** <steps>
**Worth re-checking:** <areas, or "None">
```
