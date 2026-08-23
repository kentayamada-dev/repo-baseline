---
name: docs-check
description: Review every tracked file in the project against the no-duplication rule — comments vs nearby code and repo docs, docs vs code and easily found references, bilingual pairs — and flag docs and comments that have drifted from what the code actually does. Use when asked to check for duplication or stale docs.
---

# docs-check

Review every tracked file against the no-duplication rule in CLAUDE.md. When the review finds something, present each finding with its proposed fix and **wait for the user's approval before applying it** — never apply silent fixes. When it finds nothing, say so. When unsure whether a restatement aids readability or duplicates, report it as a finding anyway and let the user decide — never silently keep it.

## Scope

```bash
git ls-files
```

Review each file's comments and docs against everything else in the repo — read related files together (a script and the doc describing it, sibling docs, both halves of a bilingual pair) so cross-file duplication surfaces. In a large result, group findings by file and order them by how much text the fix removes.

## What to look for

- **Comments** say only what the nearby code and repo docs cannot tell. A comment restating the adjacent code, or content that already lives under `docs/`, is deleted or shrunk to a pointer. Keep facts recorded nowhere else — API quirks, trap interplay, portability workarounds — because losing them means redoing the investigation.
- **Docs** say only what the code and easily found online references cannot tell. Boilerplate repeated across sections becomes one statement plus references; what upstream tool documentation already explains becomes a link plus a one-line summary. Two adjacent tables or sections restating each other within one file count too.
- **Script `--help` text and runtime output are code.** What they already tell (options, what stays or changes, next steps) must not be restated in README or docs — shrink the doc side to the command plus a pointer to `--help`.
- **Upstream documentation is an easily found reference.** Feature behavior of GitHub, gh, or a tool belongs to its official docs; keep only the repo-specific reason or gotcha and link out for the rest.
- **Do not remove what something depends on.** The top comment of each script under `scripts/` is its `--help` text (CI checks neither is empty), and docs may point at specific comments (`mise.toml`, `renovate.yml`).
- **Bilingual pairs**: README.md and files under `docs/` must stay in sync with their `X.md` / `X.ja.md` counterpart (see CONTRIBUTING.md) — flag pairs whose content has drifted apart.
- **Docs and comments must match the code.** While reading related files together, flag statements that contradict what the code or config actually does — a job, flag, path, or filename that no longer exists, a described behavior the script no longer has. Propose updating (or deleting, if the no-duplication rule says the code speaks for itself) the stale text; never "fix" the code to match a stale doc without asking.
