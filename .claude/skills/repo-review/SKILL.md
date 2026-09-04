---
name: repo-review
description: Review the whole repository from one or more perspectives — security, shell, ci, template, docs — by fanning out to the read-only reviewer subagents under .claude/agents/, re-verifying every finding against the files, and presenting what survives for approval. Every finding is written to a gitignored report file as soon as it is settled, so a long or interrupted review loses nothing and can be resumed.
disable-model-invocation: true
argument-hint: "[security|shell|ci|template|docs|all]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
---

# repo-review

Review the repository from the perspectives named in `$ARGUMENTS` (default `all`). Each perspective is one subagent under `.claude/agents/`, whose file says what it looks for; this skill only dispatches, verifies, records, and reports. Present each finding with its proposed fix and **wait for the user's approval before applying it** — never apply silent fixes. When a perspective finds nothing, say so.

| Argument | Subagent |
| --- | --- |
| `security` | `security-reviewer` |
| `shell` | `shell-reviewer` |
| `ci` | `ci-reviewer` |
| `template` | `template-reviewer` |
| `docs` | `docs-reviewer` |
| `all` | every row above |

An argument not in the table is a question for the user, not a guess.

## Report file

`.claude/review/<perspective>.md` (gitignored, one file per perspective) is the working memory of the review: every finding goes into it the moment it is settled, one entry at a time, never as a batch at the end. A long review loses the early findings from context otherwise, and a review interrupted by a question or a new session resumes from these files. They are the source the chat report is written from, not a substitute for it. A perspective's file is written even when it found nothing, and a run never touches the files of perspectives it was not asked for, so each perspective can be re-reviewed on its own.

One entry per finding:

```text
- <file>:<line> | severity: <high|medium|low> | status: <status>
  - evidence: <quoted from the file>
  - why it matters: ...
  - fix: <proposed, not applied>
  - note: <what would settle it / why dropped / why declined>
```

Status moves forward only: `pending` (recorded from the subagent, not yet checked) → `verified` / `unverified` / `dropped` → `approved` / `declined` → `applied`. Dropped and declined entries stay in the file with their reason, so a resumed run does not re-check them and the user can see what was rejected.

## Steps

1. **Start.** If any selected perspective already has a file, ask the user once, naming those perspectives, whether to resume from them or discard them and start those perspectives over; do not guess. A resumed run picks up where the statuses leave off: a selected perspective without a file is dispatched, `pending` entries are verified, and the rest are presented as they stand.
2. **Dispatch.** Launch every selected subagent with the Agent tool (`subagent_type` = the subagent's name) **in one message so they run in parallel**, each with the task text below. One perspective per subagent — do not merge two into one prompt, and do not review anything yourself at this stage. As each subagent's report arrives, write its file and record every finding as `pending` before verifying any of them.
3. **Verify.** For every `pending` entry, open the cited file at the cited line and confirm the claim holds. Update the entry as soon as it is settled: `dropped` with the reason when the claim does not hold, `unverified` with what would settle it when you cannot decide, `verified` otherwise. Report nothing you have not looked at.
4. **Report.** Read the files back and present every `verified` and `unverified` entry in chat, grouped by perspective and ordered by severity, each with its file and line, the evidence, why it matters, and the proposed fix. Then stop and wait for the user.
5. **Apply.** Record each decision as `approved` or `declined` (with the reason) as the user gives it, and mark an entry `applied` once its fix is in.

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
