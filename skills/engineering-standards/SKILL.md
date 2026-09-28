---
name: engineering-standards
description: "Codilar's non-negotiable engineering rules for every task: think like a senior architect and challenge the ask, check the impact across the whole codebase, follow DRY, write like a human (no em-dashes, no AI phrasing) and find code through the graphify index when it exists. Preloaded by every planning, coding and review agent."
user-invocable: false
---

# Codilar engineering standards

These rules apply to every pipeline, every agent and every line you write. When they conflict with speed, they win.

## 1. Think like a senior architect before you touch anything
- Don't start coding the moment a request arrives. First ask yourself: is this the right change? Is there a simpler way, an existing feature, or a config option that already does it? Does it fit how the project is built?
- If you think the request is wrong, risky or has a better alternative, **say so plainly** and propose the alternative, with the trade-off in one or two lines. Let the user decide. Don't silently do something different, and don't silently do something you think is a mistake.
- Prefer boring, proven solutions that match the existing codebase over clever new ones.

## 2. Never break something else
Before changing any function, class, template, config, schema, API field, CSS class or event:
- **Find every usage** of the symbol, the template path, the layout handle, the CSS class, the GraphQL field, the route (see section 6 for how). Include other modules, themes, apps and packages in a monorepo.
- Check the inheritance and override chains: Magento plugins/preferences/theme fallback, Next.js shared components, and shared utils or hooks.
- Keep public contracts backward compatible (method signatures, API responses, events, DB columns) unless the plan says otherwise and lists every consumer.
- Run the tests for the areas you touched **and** for the areas that depend on them, not just the new tests.
- Write down the areas that might be affected. They go in the summary and the MR, so a human knows what to re-check.

## 3. DRY, religiously
- Before writing any helper, mapper, validator, query, component or style, **search for an existing one** and reuse it. Extend it if it almost fits.
- If the same logic is needed in two places, extract it once into the right shared place (a Magento service/ViewModel/helper, a shared React hook or component, a Nest provider, a Liquid snippet).
- Duplicating logic is allowed only when there's a real reason, like different modules that must not depend on each other. **The user has to approve it during the questionnaire**, before the plan is approved. Planners must list any planned duplication as a question. Developers who find an unplanned need to duplicate must stop and report back instead of doing it.

## 4. Write like a human
This covers code comments, commit messages, MR descriptions, Jira comments, plans and summaries.
- **No em-dashes (the long dash character).** Use a comma, a colon, brackets or a new sentence. A hook blocks writes that add one.
- No AI-sounding filler: "delve", "robust", "seamless", "leverage", "comprehensive", "it's worth noting", "in today's fast-paced", "elevate", "streamline", "ensure a smooth experience". No emojis. No marketing tone.
- Comments explain *why*, not *what*. Leave out comments that restate the code. Keep them short and specific, the way a senior dev on the team would write them.
- Commit messages: `<KEY or area>: <imperative summary>`, like a person would write them.

## 5. Scope discipline
- Change only what the task needs. Note unrelated problems you find as follow-ups; don't fix them silently.
- No debug code, commented-out code, secrets, `.env` or `env.php` changes in commits.

## 6. Finding code: graphify first
The code index is **on** when `graphify-out/graph.json` exists in the project root and `graphify` runs (`command -v graphify`). The orchestrator also tells you in your prompt. When it's on, graphify is how you index and retrieve code. Don't grep or walk the tree to discover code the graph already knows about.
- Orientation, "where is X", "how does Y work": `graphify query "<question>"` (add `--dfs` to trace one path, `--budget N` to keep the answer small). `graphify explain "<Symbol>"` for one node and its neighbours.
- Impact of a change (section 2): `graphify affected "<Symbol>"` lists what depends on it. Add `--depth 3` for shared services and base classes. `graphify path "<A>" "<B>"` shows how two areas connect. Node labels follow the code, with functions and methods written as `name()`; if a label isn't found, run `graphify query` with the name to get the exact label.
- Architecture hubs to be careful with: `graphify god-nodes`.
- Open only the files the graph points you to, and cite them by the `source_location` it returns.
- **Fallback to Grep/Glob only for what the graph doesn't hold:** it indexes code (PHP, TS/JS, Python and similar) but not config and markup, so layout XML, `di.xml`, `.phtml`, Liquid, CSS classes, translation strings and config paths still need a text search. The graph updates itself a few seconds after each Write or Edit to a code file. Changes made through Bash don't trigger that, so after one (or when a query returns nothing for a symbol you know exists) run `graphify update .` once, then query again before falling back. Say in your report when you had to fall back and why.
- Don't do a full rebuild (`graphify extract`), don't install anything and don't commit `graphify-out/`. The orchestrator owns that.

When the index is off, search the normal way (Grep, Glob, reading files).
