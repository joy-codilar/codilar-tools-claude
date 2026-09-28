---
name: nextjs
description: "Next.js conventions for Codilar headless storefronts and custom frontends - App vs Pages Router, server/client components, data fetching and caching, server actions, route handlers, env vars, images, SEO, and testing. Use whenever changing a Next.js app (together with headless-backends for Magento/Shopify/Akinon, or with nestjs for custom builds)."
user-invocable: false
---

# Next.js

## First, detect the setup
- **App Router** (`app/`) or **Pages Router** (`pages/`)? Follow whichever the feature area already uses. Don't mix them within a feature.
- Look at the data layer (Apollo / urql / graphql-request / fetch wrapper / RTK Query / tRPC), the state library, the styling (Tailwind / CSS modules / styled-components) and the i18n setup. Reuse them. Don't introduce new libraries without flagging it in the plan.
- The backend is in `delivery.json` → `components[].backend`. Load the `headless-backends` skill for commerce API specifics.

## App Router rules
- Components are **server components by default**. Add `'use client'` only where you need state, effects or browser APIs, and keep client components small (leaf-level).
- Fetch data in server components or `route.ts` handlers. Set caching explicitly: `fetch(url, { next: { revalidate: N, tags: [...] } })` or `cache: 'no-store'` for per-user data (cart, account). Invalidate with `revalidateTag` / `revalidatePath`.
- Mutations: server actions or route handlers. Validate input on the server (zod if present).
- `loading.tsx` / `error.tsx` / `not-found.tsx` for every new route segment that fetches.
- SEO: `generateMetadata`, canonical URLs, structured data (JSON-LD) for PDP/PLP, `sitemap.ts` / `robots.ts` if the project owns them.

## General
- **Secrets never go to the client.** Only `NEXT_PUBLIC_*` vars are exposed. Commerce admin/integration tokens stay server-side. Add new vars to `.env.example` and list them in the MR.
- Use `next/image` with proper `sizes`, and `next/link`. Don't block the main thread. Lazy-load heavy client components with `dynamic()`.
- Per-user data (cart, customer) must never be cached in a shared cache or ISR page.
- Accessibility: semantic elements, labelled inputs, focus management for modals/drawers.
- TypeScript: no `any` in new code. Type API responses (generated GraphQL types if the project has codegen: run it after schema/query changes).

## Testing
- Unit/component: jest or vitest + React Testing Library (use whatever is configured). Cover components with logic, hooks, utils, API mappers and server actions. Mock network at the fetch/client layer (msw if present).
- `npx tsc --noEmit`, `npm run lint`, `npm run build`. **`next build` must pass**: it catches server/client boundary and type errors.
- E2E: if Playwright/Cypress exists, add or extend a spec for the changed user flow and run it against `localUrl`/`npm run dev`.
