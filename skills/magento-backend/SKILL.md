---
name: magento-backend
description: "Magento 2 / Adobe Commerce backend conventions for Codilar projects - modules, DI, plugins, declarative schema, patches, service contracts, GraphQL/REST, admin config, cron, caching and PHPUnit testing. Use whenever changing PHP/XML inside app/code or planning Magento backend work."
user-invocable: false
---

# Magento 2 / Adobe Commerce backend

## Golden rules
- **Never edit `vendor/`, core files or `generated/`.** Customise with modules in `app/code/<Vendor>/<Module>`. Use the vendor namespace the project already uses (look in `app/code/`). Use `Codilar` only for brand-new projects.
- Extend in this order: **plugin (before/after) → event observer → preference (last resort)**. Use an around plugin only when you have to change whether the original gets called.
- Constructor DI only. **Never use `ObjectManager::getInstance()`**. For heavy dependencies that aren't always used, use `Proxy`. For new entity instances, use a `Factory`.
- Prefer service contracts (`Api/*RepositoryInterface`, `Api/Data/*Interface`) and `SearchCriteriaBuilder` over direct collections in new public code.
- Match the PHP version in `composer.json`. Use typed properties, return types, constructor property promotion where the codebase already does, and `declare(strict_types=1);` in new files.

## Module anatomy
`registration.php`, `etc/module.xml` (add `<sequence>` for modules you depend on), `composer.json`, `etc/di.xml` and area-specific `etc/frontend|adminhtml|graphql|webapi_rest/di.xml`.

| Need | Where |
|---|---|
| DB tables/columns | `etc/db_schema.xml`, then `php bin/magento setup:db-declaration:generate-whitelist --module-name=Vendor_Module` (commit `db_schema_whitelist.json`) |
| Data/config changes | `Setup/Patch/Data/*.php` implementing `DataPatchInterface` (plus `PatchRevertableInterface` if needed). **Never** InstallSchema/UpgradeData |
| Admin config | `etc/adminhtml/system.xml`, defaults in `etc/config.xml`, ACL in `etc/acl.xml`. Read values through a `Config` class wrapping `ScopeConfigInterface` |
| REST | `etc/webapi.xml` + service contract + ACL resource |
| GraphQL | `etc/schema.graphqls` + resolver implementing `ResolverInterface`. Add `@cache(cacheIdentity: ...)` for cacheable queries. Check the customer context via `$context->getExtensionAttributes()->getIsCustomer()` |
| Cron | `etc/crontab.xml`. Keep jobs idempotent. Lock long jobs |
| Async | message queue (`communication.xml`, `queue_*.xml`) for heavy work triggered by the storefront |
| Admin grids/forms | UI components in `view/adminhtml/ui_component` |
| Logging | inject `Psr\Log\LoggerInterface`. Use a custom virtual-type logger for module-specific log files |

## Adobe Commerce (EE) gotchas
- Content staging: catalog/CMS/sales-rule entities are keyed by **`row_id`**, not `entity_id`. Use `MetadataPool`/`EntityManager` or repositories rather than raw SQL joins on `entity_id`.
- B2B modules (shared catalog, company, negotiable quote) change price and visibility logic. Check whether they're enabled before touching pricing or catalog permissions.

## Performance and caching
- Don't put `cacheable="false"` on a layout block. It disables FPC for the whole page. Use customer-data sections (private content) or ESI instead.
- Avoid loading models in loops (N+1). Use collections with `addFieldToSelect` and joins, or batch repositories.
- New cacheable data needs cache tags (`IdentityInterface`) so it gets invalidated correctly.

## Security
- Escape all output in templates (`$escaper->escapeHtml/Url/HtmlAttr/Js`).
- Validate the form key on POST controllers (`HttpPostActionInterface` + CSRF).
- Every admin controller/endpoint gets an ACL resource. Use bound parameters in any SQL.

## Testing (native / Valet: call `php`/`vendor/bin` directly)
- Unit tests go in `<Module>/Test/Unit/...`, mirroring the class path. Use PHPUnit mocks (`createMock`). Every new model, plugin, resolver and observer with logic gets at least a happy-path and an edge-case test.
  Run: `vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist app/code/Vendor/Module/Test/Unit`
- Static checks: `vendor/bin/phpcs --standard=Magento2 app/code/Vendor/Module` and `vendor/bin/phpstan analyse app/code/Vendor/Module` (use the project's level if configured).
- Integration/API tests only if the project already has `dev/tests/integration/phpunit.xml` configured. They need a dedicated DB.
- Verify on the running instance: `php bin/magento setup:upgrade` (new module/schema/patch), `php bin/magento cache:clean`. After constructor changes in developer mode, delete `generated/code/Vendor/Module`. Then check the page/API with curl.
- `php bin/magento module:status Vendor_Module` confirms the module is enabled.

## Deployment notes to report
Say whether the change needs `setup:upgrade`, `di:compile`, a reindex (which indexers), new config values, or a cron/consumer restart.
