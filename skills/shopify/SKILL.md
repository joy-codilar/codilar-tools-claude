---
name: shopify
description: "Shopify development conventions - Online Store 2.0 themes (Liquid, JSON templates, sections, blocks, settings schema, locales), Shopify apps (CLI, Admin GraphQL, webhooks, extensions, Functions) and Hydrogen storefronts. Use whenever working in a Shopify theme, app or Hydrogen repo."
user-invocable: false
---

# Shopify

First work out which kind of repo this is (the `delivery.json` component subtype tells you): **theme**, **app** (`shopify.app.toml`) or **hydrogen** (`@shopify/hydrogen`).

## Themes (Online Store 2.0)
- Structure: `layout/`, `templates/*.json` (section composition), `sections/`, `blocks/` (theme blocks), `snippets/`, `assets/`, `config/settings_schema.json`, `config/settings_data.json`, `locales/*.json`.
- **Don't hand-edit `config/settings_data.json` or `templates/*.json` merchant settings** unless the ticket asks for it. Merchants edit those in the theme editor, and the changes get overwritten.
- New features should be **sections/blocks with a `{% schema %}`**, so merchants can configure them. Give each one sensible defaults and a `presets` entry so it shows up in the editor.
- All user-facing strings go in `locales/en.default.json` (plus schema translations in `*.schema.json`). Use `{{ 'key' | t }}`.
- Performance: `image_url` + `image_tag` with `widths`/`sizes`, `loading: 'lazy'` below the fold. No render-blocking JS; use `defer`. Avoid heavy Liquid loops over `collections.all`.
- Data: prefer **metafields/metaobjects** over hard-coded content. Reference them as `product.metafields.namespace.key`.
- JS: vanilla or web components (custom elements), matching the theme (Dawn-style). Don't add jQuery.
- Accessibility: semantic HTML, focus states, ARIA on interactive components, and keyboard support for drawers and modals.
- Commands: `shopify theme check` (lint, must pass). `shopify theme dev --store <store>` is for manual preview. **Never `shopify theme push` or `publish` to the live theme.** A push to an unpublished dev theme needs the user's explicit OK.

## Apps
- Shopify CLI app (usually the Remix / React Router template). Use the Admin **GraphQL** API, never REST, for new code, and pin the API version to the one in `shopify.app.toml`.
- Declare scopes in `shopify.app.toml`. Adding a scope forces merchants to re-authorise, so call it out in the MR.
- Webhooks: declare them in the toml, verify HMAC (the framework helpers do this) and keep handlers idempotent.
- Extensions go under `extensions/`: theme app extensions (app blocks), checkout UI extensions, Shopify Functions (discounts, delivery, payment customisations). Each has its own toml and tests.
- UI: Polaris / App Bridge components, matching what's already in use.

## Hydrogen
- A React Router/Remix-based storefront on the **Storefront API**. Data loads in route `loader`s via `context.storefront.query()` with GraphQL fragments. Use caching strategies (`CacheShort`, `CacheLong`).
- Cart through Hydrogen's cart helpers. Markets through `@inContext(country:, language:)`.
- See the `headless-backends` skill (Shopify section) for Storefront API specifics.

## Testing
- Themes: `shopify theme check` plus a manual/preview check of the section in the editor (list the steps in the MR). If there's a `localUrl` or preview URL, run a Playwright smoke test.
- Apps/Hydrogen: `npm test` (vitest/jest) for loaders, actions, utils and Functions (Functions have their own test runner in the extension folder), plus `npm run build` and `npm run lint`.
