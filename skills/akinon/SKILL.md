---
name: akinon
description: "Akinon Commerce Cloud conventions - ProjectZero (@akinon/next) Next.js storefronts, pz plugins, akinon.json, and Akinon backend extensions. Use whenever working in an Akinon storefront or extension repo."
user-invocable: false
---

# Akinon

Akinon Commerce Cloud (ACC) has three parts: **Omnitron** (back office: catalog, orders, integrations), **Commerce** (the storefront API) and **storefront apps**, usually built on **ProjectZero Next** (`@akinon/next`, a Next.js framework).

> Akinon conventions change between framework versions. **Before planning, read the repo's README, `package.json`, `akinon.json` and a couple of existing pages or components**, and follow what's there over anything generic below. When unsure, check docs.akinon.com.

## ProjectZero storefronts (`@akinon/next`)
- It's a Next.js app with a framework layer. **Never edit `node_modules/@akinon/*`.** Customise through the project's `src/` (components, views, routes) and the framework's documented extension points.
- Commerce data (products, lists, basket, checkout, account) goes through the framework's data/API layer: the helpers and hooks `@akinon/next` exports. Don't write raw fetches to the Commerce API when the framework already has a helper.
- **Plugins** (`@akinon/pz-*`: payment options, one-click checkout, B2B, etc.) are enabled in the project's plugin config. Check which ones are installed before building something that may already exist as a plugin.
- Routing is locale/currency aware. New pages must work under every configured locale. Put text in the translation files, never hard-coded.
- Checkout is **server-driven and step-based**: the Commerce API tells the client which checkout step or page comes next. Extend the existing checkout step components. Don't bypass the flow.
- Settings and environments live in the project's settings file and in env vars. Never hard-code the Commerce URL or keys.

## `akinon.json`
The ACC app manifest (app type, build/runtime configuration). Change it only if the ticket needs it (e.g. a new env variable or runtime setting), and call it out in the MR because it affects deployment on ACC.

## Backend extensions
- These are ACC extension apps (integrations, custom endpoints) that talk to Omnitron/Commerce APIs. Follow the extension's existing structure and API client.
- Keep them idempotent and retry-safe for integration jobs (order/stock/price sync). Log with correlation ids.

## Testing
- `npm run lint`, `npx tsc --noEmit`, `npm test` (if jest/vitest is set up) and `npm run build`. The build must pass: ACC builds from the repo.
- Smoke test the affected route on `localUrl` (`npm run dev`, or whatever the project's dev command is) for each configured locale, and check the console for errors.
