---
name: magento-hyva
description: "Hyvä theme conventions for Magento 2 - Tailwind CSS, Alpine.js components in phtml, ViewModels, hyva compat modules, private content events, Tailwind build and purge rules, CSP-safe Alpine. Use whenever changing a Hyvä-based theme or a module's Hyvä templates."
user-invocable: false
---

# Hyvä frontend (Magento 2)

## Mental model
Hyvä replaces RequireJS, KnockoutJS and jQuery with **Tailwind CSS + Alpine.js**. Don't add jQuery or RequireJS code to Hyvä templates. Luma code (`data-mage-init`, `x-magento-init`, KO templates) doesn't run on Hyvä pages.

## Where things go
- Child theme: `app/design/frontend/<Vendor>/<theme>/` with `<parent>Hyva/default</parent>` (or the project's parent), templates in `<Vendor_Module>/templates/`.
- Tailwind: `web/tailwind/` (`tailwind.config.js`, `tailwind-source.css`, `package.json`).
- Third-party modules need a **Hyvä compatibility module** (e.g. `Hyva_<Module>Compat` or a custom one) to supply Hyvä templates. Check whether one exists before writing your own.

## Templates
- Get helpers through the view model registry: `$viewModels = $block->getData('viewModels'); $vm = $viewModels->require(\Vendor\Module\ViewModel\Foo::class);`. For icons: `$heroicons = $viewModels->require(\Hyva\Theme\ViewModel\HeroiconsOutline::class);`.
- Alpine: `x-data="initFoo()"` with a function defined in a `<script>` right after the element. Namespace the function names to avoid collisions (`initVendorFoo_<?= $block->getNameInLayout() ?>` style when repeated).
- **CSP:** if the project uses the Hyvä CSP-compatible theme/Alpine build, don't use inline expressions in attributes (e.g. `@click="open = !open"`). Define methods in the component and register them the way the existing templates do. Mirror the existing pattern.
- Private content: listen for `private-content-loaded.window` to read customer/cart sections. Trigger a refresh with `window.dispatchEvent(new CustomEvent('reload-customer-section-data'))`.
- Forms: include `<?= $block->getBlockHtml('formkey') ?>`. Use `hyva.getFormKey()` / `hyva.postForm()` helpers where the theme provides them.
- Escape output with `$escaper` exactly as in Luma.

## Tailwind rules
- Purging scans templates: **class names must appear as complete literal strings**. No `'text-' . $color`. Use a lookup map of full class names, or safelist them in `tailwind.config.js`.
- If a module has its own Tailwind sources, make sure it's registered: run `php bin/magento hyva:config:generate` so `app/etc/hyva-themes.json` includes it.
- Use the theme's design tokens (colors/spacing in `tailwind.config.js`) rather than arbitrary values.

## Checkout
The project may use **Luma checkout fallback** (profile `hyva+luma`) or **Hyvä Checkout** (Magewire/Livewire-style components). Check `composer.json` for `hyva-themes/magento2-hyva-checkout` before planning checkout work. Luma fallback changes follow the `magento-luma` skill.

## Build and verify (native / Valet)
1. `npm --prefix app/design/frontend/<Vendor>/<theme>/web/tailwind ci` (first time only), then `npm --prefix app/design/frontend/<Vendor>/<theme>/web/tailwind run build-prod`. Commit the generated `web/css/styles.css` only if the project already commits it.
2. `php bin/magento cache:clean layout block_html full_page`
3. Test behaviour, not looks: `curl -sI` for status, then a Playwright spec that asserts the markup, the Alpine interaction (clicking toggles the state, the form submits, the cart section refreshes) and no console errors, at desktop and mobile viewports. No screenshot checks. Ask the user only if a purely visual detail can't be asserted.
