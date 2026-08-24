#!/usr/bin/env bash
#
# PostToolUse(Write|Edit) hook: reads the tool-call JSON on stdin and, when the
# edited file is README or a docs/ page, reminds that its English/Japanese
# counterpart must change in the same PR (CONTRIBUTING.md).

jq -c 'if ((.tool_input.file_path // "")
    | test("README(\\.ja)?\\.md$|/docs/[^/]+\\.md$"))
  then {hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "Bilingual-pair rule (CONTRIBUTING.md): this file has an English/Japanese counterpart (X.md / X.ja.md). Update the counterpart in the same PR (English first)."}}
  else empty end'
