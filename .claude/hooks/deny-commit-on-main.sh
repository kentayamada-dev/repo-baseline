#!/usr/bin/env bash
#
# PreToolUse(Bash) hook: reads the tool-call JSON on stdin and denies a git
# commit while the checkout is on main (CLAUDE.md: every change lands through
# a PR from a working branch).
#
# A compound command may create the branch and commit in one Bash call, so the
# first branch creation (checkout -b / switch -c / switch --create) is compared
# by offset against the first commit: branching first is allowed. The flag has
# to stand on its own (-c feat, not -cfeat) to count as one. [^|;&] keeps each
# match inside one pipeline segment. Matching is textual, not a shell parse, so
# a command that merely quotes the words (echo "git commit") is still denied on
# main — a cheap false positive. `strings` drops a tool call whose command is
# not text: there is nothing to read there, and a verdict must never rest on a
# guess.

if jq -e '
    (.tool_input.command // "" | strings) as $c
    | ([$c | match("\\bgit\\b[^|;&]*\\bcommit\\b").offset] + [null])[0] as $commit
    | ([$c | match("\\bgit\\b[^|;&]*\\b(checkout|switch)\\b[^|;&]*\\s(-b|-c|--create)\\b").offset] + [null])[0] as $branch
    | ($commit != null) and ($branch == null or $branch > $commit)
  ' >/dev/null && [ "$(git branch --show-current 2>/dev/null)" = "main" ]; then
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "CLAUDE.md: never commit on main — create a working branch from the latest remote main first."}}'
fi
