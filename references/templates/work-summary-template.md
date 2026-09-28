# Work summary template: `.claude/work/<ID>.md`

Written when the task is done, and committed with the MR (in the final commit, together with the plan). Plain language: a developer or QA person picking this up in six months should understand it without opening the chat.

```markdown
# <ID>: <title>

Date: <YYYY-MM-DD> · Pipeline: <deliver | deliver-ticket> · Plan: `.claude/plans/<ID>.md`

## 1. What was the ask
<2 to 5 sentences. For tickets, link the Jira issue.>

## 2. What was the plan
<A short version of the approved approach and work units. Include any refinements accepted during the run.>

## 3. Questions asked
1. <question>
2. <question>

## 4. What the user answered
1. <answer>
2. <answer>

## 5. Files changed
| File | Change |
|---|---|
| `path/to/file` | <one line> |

## 6. Branch and commits
- Branch: `<branch>` into `<target branch>`
- MR: <url>
- Commits:
  - `<short sha>` <message>
  - `<short sha>` <message>

## 7. How it was tested
| # | Case | Type (unit / API script / Playwright / build / manual) | Result |
|---|---|---|---|
Commands run: `<command>`, `<command>`
Areas covered: <list>

## 8. How to check the acceptance criteria
1. <step, URL, expected result> (AC 1)
2. <step> (AC 2)

## 9. Other areas that might be affected (worth a re-check)
- <area and why>

## Parked / follow-ups
- <item>
```
