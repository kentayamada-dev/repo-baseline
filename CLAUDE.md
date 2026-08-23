# CLAUDE.md

## Critical rules

- When the user's intent or the implementation approach is unclear, or you are torn between approaches, ask the user right away instead of guessing
- README.md and the files under `docs/` are bilingual pairs (`X.md` English-first + `X.ja.md`, same PR — see CONTRIBUTING.md); everything else is English-only, code comments included
- PR titles must follow Conventional Commits — on squash merge the PR title becomes, verbatim, the commit title on main

## Project overview

A template repository providing groundwork for repository operations: branch protection, CI, Renovate. It contains no application code — changes here are to workflows, scripts, and documentation.

## Documentation

- No duplication: comments say only what the nearby code and repo docs cannot tell; repo docs say only what the code and easily found online references cannot tell

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
- Per-job details: [docs/ci-jobs.md](docs/ci-jobs.md)
