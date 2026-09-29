---
name: nestjs
description: "NestJS backend conventions for Codilar custom builds - modules, controllers, providers, DTO validation, guards, interceptors, config, ORM and migrations, OpenAPI, and unit/e2e testing. Use whenever changing a NestJS API (often paired with a Next.js frontend in the same repo)."
user-invocable: false
---

# NestJS

## First, detect the setup
Look at the ORM (TypeORM / Prisma / Mongoose / MikroORM), the auth approach (JWT / Passport strategies / sessions), the config (`@nestjs/config`, schema validation), the queue (BullMQ) and whether it's a monorepo (Nx / Turborepo / pnpm workspaces). Follow the existing module layout.

## Rules
- **One feature = one module** (`*.module.ts`, `*.controller.ts`, `*.service.ts`, `dto/`, `entities/`). Controllers stay thin. Business logic lives in services.
- **Validate every input** with DTOs (`class-validator` + `class-transformer`) and a global or route `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })`, or zod if that's the project's choice.
- **Protect every new endpoint** with the project's guards (auth + roles/permissions). Say explicitly in the plan if an endpoint is meant to be public.
- Errors: throw Nest HTTP exceptions (or the project's domain errors mapped by an exception filter). Never leak stack traces or DB errors to clients.
- Config through `ConfigService`, never `process.env` scattered around. Add new vars to the config schema and `.env.example`.
- **Database:** schema changes go through **migrations** (TypeORM migrations / `prisma migrate dev --name ...`). **Never `synchronize: true`** outside local. Migrations must be reversible.
- Use transactions for multi-write operations. Add indexes for new query patterns.
- OpenAPI: add `@ApiTags`, `@ApiProperty` and response decorators if Swagger is set up. The Next.js frontend may generate types from it.
- Logging through the Nest `Logger` or the project's logger, with no PII or secrets.
- For shared contracts with the Next.js app (monorepo), update the shared types package instead of duplicating them.

## Testing
- Unit: `Test.createTestingModule` with mocked providers. Cover the service logic, guards and pipes. Aim for happy path + validation failure + auth failure for each new endpoint.
- E2E: `test/*.e2e-spec.ts` with supertest against the app module (use a test DB or the project's testcontainers setup, if any), plus a Playwright `request` spec against the running API for each new or changed endpoint.
- `npm run lint`, `npm test`, `npm run test:e2e` (if configured), `npm run build`.
