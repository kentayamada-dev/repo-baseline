---
name: repo-review
description: Review the whole repository from one or more perspectives — security, shell, ci, template, docs — by fanning out to the read-only reviewer subagents under .claude/agents/, re-verifying every finding against the files, and presenting what survives for approval.
disable-model-invocation: true
argument-hint: "[security|shell|ci|template|docs|all]"
allowed-tools:
  - Read
  - Grep
  - Glob
---

# repo-review

Review the repository from the perspectives named in `$ARGUMENTS` (default `all`). Each perspective is one subagent under `.claude/agents/`, whose file says what it looks for; this skill only dispatches, verifies, and reports. Present each finding with its proposed fix and **wait for the user's approval before applying it** — never apply silent fixes. When a perspective finds nothing, say so.

| Argument | Subagent |
| --- | --- |
| `security` | `security-reviewer` |
| `shell` | `shell-reviewer` |
| `ci` | `ci-reviewer` |
| `template` | `template-reviewer` |
| `docs` | `docs-reviewer` |
| `all` | every row above |

An argument not in the table is a question for the user, not a guess.

## Steps

1. **Dispatch.** Launch every selected subagent with the Agent tool (`subagent_type` = the subagent's name) **in one message so they run in parallel**, each with the task text below. One perspective per subagent — do not merge two into one prompt, and do not review anything yourself at this stage.
2. **Verify.** For every finding that comes back, open the cited file at the cited line and confirm the claim holds. Drop what does not hold. Keep a finding you cannot settle, but mark it as unverified and say what would settle it. Report nothing you have not looked at.
3. **Report.** Group the survivors by perspective, order each group by severity, and give each finding its file and line, the evidence, why it matters, and the proposed fix. Then stop and wait for the user.

## Task text for each subagent

Pass this verbatim, with the working directory filled in:

```text
Review the repository at <working directory> from your perspective only. Read-only: do not edit anything.
Report each finding as:
- file:line
- severity: high / medium / low
- what is wrong, quoting the evidence from the file
- why it matters in this repository
- the proposed fix, described but not applied
When you are unsure whether something is a problem, report it with severity low and say what would settle it.
When there is nothing to report, say so explicitly.
```
