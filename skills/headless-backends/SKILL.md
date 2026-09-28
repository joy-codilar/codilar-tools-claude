---
name: headless-backends
description: "How headless frontends (Next.js, React Native) talk to commerce backends - Magento GraphQL, Shopify Storefront API, and Akinon Commerce API - covering auth, carts, caching, store/market context and error handling. Use whenever a Next.js or React Native change reads or writes commerce data."
user-invocable: false
---

# Commerce backends for headless frontends

Always reuse the repo's existing API client, queries/fragments and types. The notes below are about the backend's behaviour, which you must respect.

## Magento GraphQL (`/graphql`)
- **Store context:** send the `Store: <store_code>` header on every request. `Content-Currency` if multi-currency.
- **Auth:** `generateCustomerToken` → `Authorization: Bearer <token>`. Tokens expire; handle `graphql-authorization` errors by logging the user out or refreshing.
- **Carts:** guests use `createGuestCart`/`createEmptyCart` and a cart id you store client-side. Logged-in users use `customerCart`. After login, call `mergeCarts(source_cart_id, destination_cart_id)`. Use `addProductsToCart` (not the legacy per-type mutations) for new code.
- **Errors come back with HTTP 200** in the `errors[]` array, and `addProductsToCart` returns `user_errors`. Always check both.
- **Caching:** queries can be sent as GET and are cached by Varnish/FPC. Use GET for catalog/CMS queries, POST for mutations and anything per-customer. Respect `X-Magento-Cache-Id` if the project uses it.
- Routing: `route(url:)` (2.4.5+) or `urlResolver` resolves SEO URLs to product/category/CMS.
- New fields or queries needed from Magento → that's a backend unit (`schema.graphqls` + resolver) for `magento-backend-developer`, or an external dependency if the backend repo is separate.

## Shopify Storefront API
- Endpoint: `https://<shop>.myshopify.com/api/<version>/graphql.json`. Pin the version the repo uses.
- Tokens: the **public** token (`X-Shopify-Storefront-Access-Token`) is fine in the browser/app. The **private** token (`Shopify-Storefront-Private-Token`) is server-side only.
- **Cart API:** `cartCreate`, `cartLinesAdd`/`Update`/`Remove`, `cartBuyerIdentityUpdate`. Checkout goes through `cart.checkoutUrl`. Don't try to rebuild Shopify checkout.
- **Markets/i18n:** add `@inContext(country: XX, language: YY)` to queries for localised prices and content.
- Customer: the Customer Account API (new) or legacy `customerAccessTokenCreate`. Follow what the repo uses.
- Rate limits are cost-based. Request only the fields you need and use fragments.
- Data not in the Storefront API (e.g. custom data) → metafields/metaobjects exposed to the storefront. Enabling that is a Shopify admin/app change, so note it as a dependency.

## Akinon Commerce API
- A REST API served by the Commerce layer. It's session/cookie based, with CSRF protection on mutating requests, so the client has to forward cookies and the CSRF token the way the existing client does. Check the repo's client for the exact headers.
- Basket and checkout are **server-driven**: checkout advances through steps the API returns (address → shipping → payment → confirmation). Always render the step the API says is next.
- Locale/currency come from the URL or request context. Pass them the way the existing client does.
- If the storefront uses `@akinon/next`, use its data hooks and helpers instead of calling the API directly (see the `akinon` skill).

## Common rules
- Never expose admin/integration tokens (Magento integration tokens, Shopify Admin API tokens, Omnitron credentials) to the client or the app bundle.
- Map backend responses to the app's own domain types in one place (adapter/mapper). Unit-test those mappers with fixture payloads.
- Every commerce call needs a loading state, an error state (including partial `user_errors`) and a retry/empty state.
