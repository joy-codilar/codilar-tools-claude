# Plan file template: `.claude/plans/<ID>.md`

`<ID>` is the Jira key (e.g. `ABC-123`) or, without a ticket, a short kebab-case name (e.g. `pdp-stock-badge`). This file is committed with the MR.

```markdown
# <ID>: <title>

Status: DRAFT | AWAITING APPROVAL | APPROVED | IN PROGRESS | DONE
Pipeline: deliver | deliver-ticket
Branch: <feature|task>/<ID>

## The ask
<The requirement in business terms. For tickets: summary, key description points, and links to the ticket, epic and related issues.>

## Context
<What related tickets, comments, earlier commits and the codebase tell us. Include the likely affected areas (paths, modules, routes).>

## Acceptance criteria
1. <testable criterion>
2. <testable criterion> (derived)

## Questions and answers
| # | Question | Answer | Asked by |
|---|---|---|---|
| 1 | <question> | <user's answer, or "default accepted: ..."> | analyst / architect / refinement |

## Approach
<Short description. If the architect challenged the ask or suggested an alternative, note it here with the outcome.>

## Work units
| id | description | files | agent | depends on | size |
|---|---|---|---|---|---|

## Reuse (DRY)
<Existing utils, services and components this plan reuses. Any approved duplication, with the reason.>

## Impact analysis
<Other areas that use the code being changed and how they're protected: tests, backward compatibility.>

## Test plan
| # | case | type | AC | how |
|---|---|---|---|---|

## Deployment notes

## Risks and rollback

## Refinements
<User refinements accepted during the run, with the time and what changed.>

## Parked
<Refinements or ideas deliberately left out, with the reason.>
```
