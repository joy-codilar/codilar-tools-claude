---
name: magento-luma
description: "Magento 2 Luma/Blank-based storefront theme conventions - layout XML, phtml templates, LESS, RequireJS, jQuery widgets, KnockoutJS UI components, mixins, checkout customisation, customer-data and static content. Use whenever changing a Luma-based theme or module frontend (view/frontend) outside Hyvä."
user-invocable: false
---

# Magento Luma / Blank theme frontend

## Where things go
- Theme: `app/design/frontend/<Vendor>/<theme>/` with `theme.xml` (`<parent>Magento/luma</parent>` or `Magento/blank`), `registration.php`, `etc/view.xml` (image sizes), `web/css/source/`, `web/js/`, `i18n/en_US.csv`.
- Override a module template: `app/design/frontend/<Vendor>/<theme>/<Vendor_Module>/templates/...`. Copy the minimum and keep the original structure so upgrades diff cleanly.
- Module frontend: `app/code/<Vendor>/<Module>/view/frontend/{layout,templates,web,requirejs-config.js}`.

## Layout XML
- **Extend, don't override.** Use `<referenceBlock>`, `<referenceContainer>`, `<move>` and `<block>` in the handle file (e.g. `catalog_product_view.xml`). Avoid `layout/override/` unless there's truly no alternative.
- Remove with `<referenceBlock name="x" remove="true"/>`. Pass data with `<arguments>`. Prefer ViewModels (`<argument name="view_model" xsi:type="object">`) over custom Block classes for new logic.
- Never add `cacheable="false"`. Load per-customer data through customer-data sections.

## Styles (LESS)
- Use Magento UI library variables and mixins. Put theme tweaks in `web/css/source/_extend.less` and variables in `_theme.less`. Module styles go in `view/frontend/web/css/source/_module.less`.
- Mobile-first breakpoints use `.media-width(@extremum, @break)` mixins. Don't hard-code media queries.

## JavaScript
- RequireJS AMD modules. Initialise with `data-mage-init` or `<script type="text/x-magento-init">`. No inline `<script>` with global code.
- Change core JS with **mixins** (`requirejs-config.js` → `config.mixins`), not by copying the file.
- jQuery widgets: `$.widget('vendor.name', ...)`. KnockoutJS/UI components for checkout and minicart. Templates go in `web/template/*.html`.
- Private content: `Magento_Customer/js/customer-data` sections, declared in `etc/frontend/sections.xml` to invalidate on POST.
- Translations: `$t('...')` in JS, `__('...')` in PHP/phtml. Add strings to `i18n/en_US.csv`.

## Checkout
- Change the checkout layout through `checkout_index_index.xml` or, better, a `LayoutProcessor` plugin for dynamic fields.
- New fields need backend persistence (extension attributes + a quote/order plugin). Coordinate with `magento-backend-developer`.

## Templates
- Escape everything: `$escaper->escapeHtml()`, `escapeUrl()`, `escapeHtmlAttr()`, `escapeJs()`.
- Keep logic out of templates. Put it in a ViewModel.

## Verify (native / Valet)
1. Clear generated assets for the theme: `rm -rf pub/static/frontend/<Vendor>/<theme> var/view_preprocessed/pub/static/frontend/<Vendor>/<theme>` (ask first if the `rm` is blocked), then `php bin/magento cache:clean layout block_html full_page`.
2. In production mode, run `php bin/magento setup:static-content:deploy -f <locales> --theme <Vendor>/<theme>` instead.
3. Test behaviour, not looks: `curl -sI` for status, then a Playwright spec (`npx playwright test`) that asserts the markup, the interaction (e.g. the widget opens, the form submits, the minicart updates) and no JS console errors, at desktop and mobile viewports. No screenshot checks. Ask the user only if a purely visual detail can't be asserted.
