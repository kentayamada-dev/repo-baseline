#!/usr/bin/env bash
#
# PreToolUse(Bash) hook: reads the tool-call JSON on stdin and asks for
# confirmation when the command looks like a git commit/push or gh pr create
# (CLAUDE.md: those need an explicit user request).
#
# [^|;&] keeps each match inside one pipeline segment, so "git log | grep push"
# does not trigger. Matching is textual, not a shell parse, so a command that
# merely quotes the words (echo "git push") still asks — a cheap false positive.

jq -c 'if ((.tool_input.command // "")
    | test("\\bgit\\b[^|;&]*\\b(commit|push)\\b|\\bgh\\b[^|;&]*\\bpr\\b[^|;&]*\\bcreate\\b"))
  then {hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: "CLAUDE.md: commit/push/PR creation requires an explicit user request — confirm before running."}}
  else empty end'
