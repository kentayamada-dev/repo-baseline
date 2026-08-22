# CLAUDE.md

<!--
━━━ How to use this template (delete this entire comment block before use) ━━━

1. Replace the [e.g., ...] placeholders with your project's actual content
2. Delete any sections that don't apply (don't leave empty sections)
3. Delete all HTML comments
  (comments are loaded every session too and consume context)
4. Keep the whole file short. Aim for ~100 lines; if it grows,
  split content out via @imports or skills
5. Deletion test for every line:
  "If I remove this, will Claude make a mistake?" → If no, delete it

■ Put things in the right place
- Rules that must be enforced without exception (e.g., no direct pushes to main)
  → hooks, not CLAUDE.md (CLAUDE.md has no enforcement power)
- Domain knowledge or workflows needed only occasionally
  → .claude/skills/, not CLAUDE.md (skills are loaded on demand)
- Anything Claude can learn by reading the code, or generic advice
  ("write clean code", etc.)
  → nowhere

■ Maintenance rules
- Each time Claude makes a mistake and you correct it, add one line
  to the relevant section
- If rules stop being followed, suspect "too long" before adding more
  (prune, don't append)
- If Claude asks you something already answered in this file,
  the phrasing is probably ambiguous
- Review this file like code: prune regularly and verify that changes
  actually alter Claude's behavior
-->

## Critical rules

<!-- Only the 3–5 things that absolutely must be followed. The top of the file
carries the most weight, so be selective. Write everything in imperative
form ("never do X" — no "preferably" / "if possible") -->

- [e.g., Never commit credentials or API keys. Reference where they live, never the values (1Password "dev" vault)]
- [e.g., Never modify anything under `packages/legacy/`. If a change seems necessary, ask the user first]
- [e.g., Database migrations: generate files only. Applying them (deploy) is done by a human]

## Project overview

<!-- 2–3 lines max. Stating the purpose, users, and top priority
makes Claude's judgment business-aware -->

[e.g., Attendance-management SaaS for SMBs (B2B, multi-tenant). Data isolation between tenants is the top priority]

## Commands

<!-- Only commands Claude can't guess. Don't list standard ones like `npm install`.
A one-line note on why the standard way isn't used prevents misuse -->

```bash
make dev        # Start locally (via docker compose; running npm run dev directly fails due to missing env vars)
make test-unit  # Unit tests only (`npm test` also runs E2E and is slow — don't use it)
make db-reset   # Reset local DB (runs migrations + seeds)
```

## Code style

<!-- Only rules that differ from defaults or standard language conventions.
Imperative form -->

- [e.g., Use ES modules (import/export). CommonJS (require) is forbidden]
- [e.g., All date handling goes through `src/lib/date.ts`. Never import dayjs directly]
- [e.g., User-facing error messages in Japanese; logs in English]

## Testing

- [e.g., The test runner is vitest. Do not use jest APIs]
- [e.g., Run only the unit tests related to your change. Leave full runs to CI]
- [e.g., Tests that touch the DB use a real database via testcontainers — no mocking]

## Repository etiquette

- [e.g., Branch names follow `feat/123-short-desc` (type/issue-number-summary)]
- [e.g., Commit messages follow Conventional Commits]
- [e.g., Paste the test command you ran and its output into the PR description]

## Architecture decisions

<!-- Only the "why" that can't be inferred from reading the code.
Adding the reason (especially past failures) stops Claude from
"improving" it away -->

- [e.g., Authorization checks always happen server-side. Client-only checks are forbidden (incident in 2024)]
- [e.g., Dependencies flow one way: `api → services → repositories`. Never add reverse references]

## Environment quirks & known pitfalls

- [e.g., Both `DATABASE_URL` and `DIRECT_URL` are required (PgBouncer vs. direct connection)]
- [e.g., Setup differs on Apple Silicon → @docs/setup-apple-silicon.md]

## References

<!-- Keep details out of this file; offload them via @import (recursive up to
5 hops). For personal settings, import from your home directory instead
of the deprecated CLAUDE.local.md -->

- Full project overview: @README.md
- Git workflow details: @docs/git-workflow.md
- Personal settings (not committed to the repo): @~/.claude/my-project-instructions.md
