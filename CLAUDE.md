# CLAUDE.md

## Critical rules

- Always respond to the user in Japanese
- README.md and the files under `docs/` are bilingual pairs: `X.md` (English, authoritative) and `X.ja.md`. Change both in the same PR, or write `translation-not-needed` in the PR body when no counterpart change is needed
- Write the English version first. Everything outside those pairs is English-only, code comments included
- PR titles must follow Conventional Commits — on squash merge the PR title becomes, verbatim, the commit title on main

## Project overview

A template repository providing groundwork for repository operations: branch protection, CI, Renovate. It contains no application code — changes here are to workflows, scripts, and documentation. Repositories created from this template replace this file using CLAUDE.template.md.

## Commands

```bash
mise install  # install the same check-tool versions CI uses
ec            # editorconfig-checker (the binary is named ec, not editorconfig-checker)
```

## Formatting

- Indentation must be a multiple of 2 spaces, including continuation lines inside Markdown and HTML comments (the `format` job rejects odd widths)
- Comment only what the code or README cannot tell; keep documentation wording minimal

## Repository etiquette

- main cannot be pushed to; every change lands through a PR, squash merge only (`gh pr merge --auto` merges once CI passes)
- Before committing, fetch and integrate the latest remote main, then create a working branch from it
- Claude edits files only; do not commit, push, or create a PR unless explicitly asked
- Write commit messages and PR titles/bodies in English (squash keeps both on main: the title as the commit title, the messages concatenated into its body)
- Adding a CI job means adding it to the `ci` gate job's `needs` in ci.yml (CI itself verifies the list is complete)

## References

Plain links, not @imports, to keep session context small.

- Development flow and PR title format: [README.md](README.md)
- Bilingual documentation rules: [CONTRIBUTING.md](CONTRIBUTING.md)
- Per-job details and local invocations: [docs/ci-jobs.md](docs/ci-jobs.md)
