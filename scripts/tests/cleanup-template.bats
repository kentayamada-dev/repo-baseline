#!/usr/bin/env bats
#
# cleanup-template.sh works entirely through git and the filesystem, so unlike
# the sync-repo-config.sh tests there is no gh to stub. Each test builds a
# throwaway git repository holding a miniature of the template's file tree
# (setup below), runs the copied script there, and asserts on what survives.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  REPO_COPY="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${REPO_COPY}/scripts/tests" "${REPO_COPY}/docs" \
    "${REPO_COPY}/.claude/hooks" "${REPO_COPY}/.github/workflows"
  cp "${REPO_ROOT}/scripts/cleanup-template.sh" "${REPO_COPY}/scripts/"

  # The template's own files: at least one per TARGET_GROUPS entry.
  echo '# template' >"${REPO_COPY}/README.md"
  echo '# テンプレート' >"${REPO_COPY}/README.ja.md"
  echo '# instructions' >"${REPO_COPY}/CLAUDE.md"
  echo '# jobs' >"${REPO_COPY}/docs/ci-jobs.md"
  echo '{}' >"${REPO_COPY}/.claude/settings.json"
  echo 'echo hook' >"${REPO_COPY}/.claude/hooks/hook.sh"
  echo 'placeholder' >"${REPO_COPY}/scripts/tests/cleanup-template.bats"
  echo '# contributing' >"${REPO_COPY}/CONTRIBUTING.md"
  echo '# conduct' >"${REPO_COPY}/CODE_OF_CONDUCT.md"
  echo '# security' >"${REPO_COPY}/SECURITY.md"

  # What a repository created from the template keeps using. ci.yml mentions a
  # deleted path on its second line; the mentions test pins that file:line.
  echo 'MIT' >"${REPO_COPY}/LICENSE"
  echo 'echo sync' >"${REPO_COPY}/scripts/sync-repo-config.sh"
  printf 'name: ci\n# details in docs/ci-jobs.md\n' >"${REPO_COPY}/.github/workflows/ci.yml"

  git -C "${REPO_COPY}" init -q -b main
  git_commit
}

# git_commit
#
# Tracks everything currently in the tree. Identity and signing are pinned so
# the run does not depend on the machine's git configuration.
git_commit() {
  git -C "${REPO_COPY}" add -A
  git -C "${REPO_COPY}" -c user.email=test@example.com -c user.name=test \
    -c commit.gpgsign=false commit -q -m fixture
}

run_cleanup() {
  bash "${REPO_COPY}/scripts/cleanup-template.sh" "$@"
}

@test "prints its usage with --help" {
  run -0 run_cleanup --help
  [ -n "${output}" ]
}

@test "refuses an unknown option" {
  run -2 run_cleanup --wat
}

@test "--dry-run lists every group and deletes nothing" {
  run -0 run_cleanup --dry-run
  [[ "${output}" == *'Documentation about the template itself'* ]]
  [[ "${output}" == *'Community documents'* ]]
  [[ "${output}" == *'Dry run: nothing was deleted.'* ]]
  [ -f "${REPO_COPY}/CLAUDE.md" ]
  [ -d "${REPO_COPY}/.claude" ]
}

@test "refuses to delete when stdin is not a terminal and --yes is absent" {
  run -2 run_cleanup </dev/null
  [[ "${output}" == *'--yes'* ]]
  [ -f "${REPO_COPY}/CLAUDE.md" ]
}

@test "--yes deletes the template's files, itself and its test included, and keeps the rest" {
  run -0 run_cleanup --yes
  [ ! -e "${REPO_COPY}/CLAUDE.md" ]
  [ ! -e "${REPO_COPY}/CONTRIBUTING.md" ]
  [ ! -e "${REPO_COPY}/docs" ]
  [ ! -e "${REPO_COPY}/scripts/cleanup-template.sh" ]
  [ ! -e "${REPO_COPY}/scripts/tests/cleanup-template.bats" ]
  [ -f "${REPO_COPY}/LICENSE" ]
  [ -f "${REPO_COPY}/scripts/sync-repo-config.sh" ]
  [ -f "${REPO_COPY}/.github/workflows/ci.yml" ]
  [[ "${output}" == *'Next steps'* ]]
}

@test "removes .claude wholesale, untracked local files included" {
  echo '{}' >"${REPO_COPY}/.claude/settings.local.json"
  run -0 run_cleanup --yes
  [ ! -e "${REPO_COPY}/.claude" ]
}

@test "leaves untracked files outside .claude where they are" {
  echo 'note' >"${REPO_COPY}/docs/notes.md"
  echo 'wip' >"${REPO_COPY}/scratch.txt"
  run -0 run_cleanup --yes
  [ ! -e "${REPO_COPY}/docs/ci-jobs.md" ]
  [ -f "${REPO_COPY}/docs/notes.md" ]
  [ -f "${REPO_COPY}/scratch.txt" ]
}

@test "writes a README stub named after the origin remote" {
  git -C "${REPO_COPY}" remote add origin https://github.com/acme/widgets.git
  run -0 run_cleanup --yes
  grep -qx '# widgets' "${REPO_COPY}/README.md"
  [ ! -e "${REPO_COPY}/README.ja.md" ]
}

@test "names the README stub after the directory when there is no remote" {
  run -0 run_cleanup --yes
  grep -qx '# repo' "${REPO_COPY}/README.md"
}

@test "writes no stub when the README is not among the deletions" {
  git -C "${REPO_COPY}" rm -q README.md README.ja.md
  git_commit
  run -0 run_cleanup --yes
  [ ! -e "${REPO_COPY}/README.md" ]
  [[ "${output}" != *'A stub'* ]]
}

@test "lists mentions of deleted paths that survive in kept files" {
  run -0 run_cleanup --dry-run
  [[ "${output}" == *'Files that stay behind mention'* ]]
  [[ "${output}" == *'.github/workflows/ci.yml:2'* ]]
}

@test "reports nothing to delete when no template file is tracked" {
  git -C "${REPO_COPY}" rm -rq --cached .
  run -0 run_cleanup
  [[ "${output}" == *'Nothing to delete'* ]]
  [ -f "${REPO_COPY}/CLAUDE.md" ]
}
