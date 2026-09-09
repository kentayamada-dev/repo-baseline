#!/usr/bin/env bats

setup() {
  load helper
  setup_repo
  stub_gh
}

@test "prints its usage with --help" {
  run -0 run_sync --help
  [ -n "${output}" ]
}

@test "refuses an unknown option, and --dry-run together with --check" {
  run -2 run_sync --wat
  run -2 run_sync --dry-run --check
}

@test "fails before reaching the API when gh or jq is missing" {
  run -1 run_sync_on_path "$(minimal_path)" --check
  [[ "${output}" == *'gh CLI is required'* ]]
  run -1 run_sync_on_path "$(minimal_path gh)" --check
  [[ "${output}" == *'jq is required'* ]]
  assert_gh_not_called 'api'
}

@test "fails before reaching the API when gh is not logged in" {
  GH_AUTH_FAILS=true run -1 run_sync --check
  assert_gh_not_called 'api'
}

@test "resolves the repository through gh when REPO is not set" {
  run -0 run_sync_unpinned --check
  [[ "${output}" == *'target: owner/repo'* ]]
  [[ "${output}" == *'no drift'* ]]
  assert_gh_called 'repo view'
}

@test "refuses when the ruleset file is missing, and applies nothing" {
  RULESET_FILE="${BATS_TEST_TMPDIR}/absent.json" run -1 run_sync
  assert_gh_not_called '--method'
}

@test "refuses broken ruleset JSON, and applies nothing" {
  echo '{' >"${REPO_COPY}/.github/rulesets/main.json"
  run -1 run_sync
  assert_gh_not_called '--method'
}

@test "refuses a ruleset that has no name, and applies nothing" {
  edit_ruleset 'del(.name)'
  run -1 run_sync
  assert_gh_not_called '--method'
}

@test "refuses a ruleset directory that holds nothing, and applies nothing" {
  rm -f "${REPO_COPY}/.github/rulesets/main.json"
  run -1 run_sync
  [[ "${output}" == *'no ruleset found'* ]]
  assert_gh_not_called '--method'
}

@test "refuses a repository that is not public, and applies nothing" {
  edit_fixture repos/owner/repo '.visibility = "private"'
  run -1 run_sync
  [[ "${output}" == *private* ]]
  assert_gh_not_called '--method'
}

@test "--check reports no drift when everything matches, and writes nothing" {
  run -0 run_sync --check
  [[ "${output}" == *'no drift'* ]]
  assert_gh_not_called '--method'
}

@test "--check reports a repository setting that differs as DRIFT" {
  edit_fixture graphql '.data.repository.hasWikiEnabled |= not'
  run -1 run_sync --check
  [[ "${output}" == *'DRIFT   has_wiki'* ]]
}

@test "--check reports settings it cannot read as UNKNOWN and points at SETTINGS_TOKEN" {
  fail_endpoint graphql 1
  run -1 run_sync --check
  [[ "${output}" == *'UNKNOWN allow_auto_merge'* ]]
  [[ "${output}" == *SETTINGS_TOKEN* ]]
}

@test "--check reports a setting the response leaves out as UNKNOWN" {
  edit_fixture graphql 'del(.data.repository.hasWikiEnabled)'
  edit_fixture repos/owner/repo 'del(.security_and_analysis)'
  run -1 run_sync --check
  [[ "${output}" == *'UNKNOWN has_wiki (not present in the response)'* ]]
  [[ "${output}" == *'UNKNOWN secret_scanning_push_protection (not present in the response)'* ]]
}

@test "a 404 on vulnerability-alerts is DRIFT with admin access, UNKNOWN without" {
  fail_endpoint repos/owner/repo/vulnerability-alerts 1 'HTTP 404: Not Found'
  run -1 run_sync --check
  [[ "${output}" == *'DRIFT   vulnerability-alerts = false'* ]]
  edit_fixture repos/owner/repo '.permissions.admin = false'
  run -1 run_sync --check
  [[ "${output}" == *'UNKNOWN vulnerability-alerts'* ]]
}

@test "--check reports an endpoint that answers disabled as DRIFT" {
  edit_fixture repos/owner/repo/immutable-releases '.enabled = false'
  run -1 run_sync --check
  [[ "${output}" == *'DRIFT   immutable-releases = false'* ]]
}

@test "--check reports push protection that is off as DRIFT" {
  edit_fixture repos/owner/repo \
    '.security_and_analysis.secret_scanning_push_protection.status = "disabled"'
  run -1 run_sync --check
  [[ "${output}" == *'DRIFT   secret_scanning_push_protection = disabled'* ]]
}

@test "--check reports the Actions GITHUB_TOKEN permissions that differ as DRIFT" {
  edit_fixture repos/owner/repo/actions/permissions/workflow \
    '.default_workflow_permissions = "write" | .can_approve_pull_request_reviews = true'
  run -1 run_sync --check
  [[ "${output}" == *'DRIFT   default_workflow_permissions = write'* ]]
  [[ "${output}" == *'DRIFT   can_approve_pull_request_reviews = true'* ]]
}

@test "--check reports the endpoints, labels and rulesets it cannot fetch as UNKNOWN" {
  fail_endpoint repos/owner/repo/private-vulnerability-reporting 1
  fail_endpoint repos/owner/repo/actions/permissions/workflow 1
  fail_endpoint repos/owner/repo/labels 1
  fail_endpoint 'repos/owner/repo/rulesets?includes_parents=false' 1
  run -1 run_sync --check
  [[ "${output}" == *'UNKNOWN private-vulnerability-reporting (cannot be fetched)'* ]]
  [[ "${output}" == *'UNKNOWN actions/permissions/workflow (cannot be fetched)'* ]]
  [[ "${output}" == *'UNKNOWN cannot fetch the list of labels'* ]]
  [[ "${output}" == *'UNKNOWN cannot fetch the list of rulesets'* ]]
  [[ "${output}" != *DRIFT* ]]
}

@test "--check reports a ruleset that is gone as DRIFT" {
  edit_fixture 'repos/owner/repo/rulesets?includes_parents=false' '[]'
  run -1 run_sync --check
  [[ "${output}" == *'DRIFT   ruleset main = (missing)'* ]]
}

@test "--check reports a ruleset it cannot fetch by id as UNKNOWN" {
  fail_endpoint repos/owner/repo/rulesets/1 1
  run -1 run_sync --check
  [[ "${output}" == *'UNKNOWN ruleset main (cannot be fetched)'* ]]
}

@test "--check reports the enforcement, the target and the targeted refs that differ" {
  edit_fixture repos/owner/repo/rulesets/1 \
    '.enforcement = "disabled" | .target = "tag" | .conditions.ref_name.include = ["refs/heads/master"]'
  run -1 run_sync --check
  [[ "${output}" == *'enforcement = disabled (expected: active)'* ]]
  [[ "${output}" == *'target = tag (expected: branch)'* ]]
  [[ "${output}" == *'conditions.ref_name.include = ["refs/heads/master"] (expected: ["refs/heads/main"])'* ]]
}

@test "--check compares the number of bypass actors" {
  edit_ruleset '.bypass_actors = [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always"}]'
  run -1 run_sync --check
  [[ "${output}" == *'bypass_actors = 0 entries (expected: 1)'* ]]
}

@test "--check pinpoints the ruleset parameter that differs" {
  edit_fixture repos/owner/repo/rulesets/1 \
    '(.rules[] | select(.type == "pull_request") | .parameters.required_review_thread_resolution) |= not'
  run -1 run_sync --check
  [[ "${output}" == *'rule pull_request parameter required_review_thread_resolution'* ]]
}

@test "--check reports rules that are missing and rules that are not in the definition" {
  edit_fixture repos/owner/repo/rulesets/1 \
    '.rules |= map(select(.type != "code_scanning")) + [{type: "creation"}]'
  run -1 run_sync --check
  [[ "${output}" == *'rule code_scanning is missing'* ]]
  [[ "${output}" == *'unexpected rule creation'* ]]
}

@test "--check is indifferent to the order the API returns rules in" {
  edit_fixture repos/owner/repo/rulesets/1 '.rules |= reverse'
  run -0 run_sync --check
  [[ "${output}" == *'no drift'* ]]
}

@test "--check reports a deleted label as DRIFT" {
  edit_fixture repos/owner/repo/labels 'map(select(.name != "maintenance"))'
  run -1 run_sync --check
  [[ "${output}" == *'DRIFT   label maintenance = (missing)'* ]]
}

@test "REPO_SETTINGS=false limits the check to the rulesets" {
  fail_endpoint graphql 1
  REPO_SETTINGS=false run -0 run_sync --check
  [[ "${output}" == *'no drift'* ]]
}

@test "--dry-run prints the plan and changes nothing" {
  run -0 run_sync --dry-run
  [[ "${output}" == *'PATCH repos/owner/repo'* ]]
  [[ "${output}" == *'EDIT  .github/ISSUE_TEMPLATE/config.yml'* ]]
  assert_gh_not_called '--method'
  grep -q 'github\.com/OWNER/REPO/' "${REPO_COPY}/.github/ISSUE_TEMPLATE/config.yml"
}

@test "REPO_SETTINGS=false limits the plan to the rulesets" {
  REPO_SETTINGS=false run -0 run_sync --dry-run
  [[ "${output}" == *'"name": "main"'* ]]
  [[ "${output}" != *PATCH* ]]
  [[ "${output}" != *EDIT* ]]
}

@test "applies the settings and updates the ruleset of the same name in place" {
  run -0 run_sync
  assert_gh_called '--method PUT repos/owner/repo/rulesets/1'
  assert_gh_not_called '--method POST repos/owner/repo/rulesets'
  assert_gh_called '--method PATCH repos/owner/repo'
  assert_gh_called '--method PUT repos/owner/repo/immutable-releases'
  assert_gh_called '--method PUT repos/owner/repo/actions/permissions/workflow'
}

@test "creates the ruleset when none of that name exists" {
  edit_fixture 'repos/owner/repo/rulesets?includes_parents=false' '[]'
  run -0 run_sync
  assert_gh_called '--method POST repos/owner/repo/rulesets'
  assert_gh_not_called '--method PUT repos/owner/repo/rulesets/1'
}

@test "applies every ruleset in the directory" {
  jq '.name = "release" | .conditions.ref_name.include = ["refs/heads/release"]' \
    "${REPO_COPY}/.github/rulesets/main.json" >"${REPO_COPY}/.github/rulesets/release.json"
  edit_fixture 'repos/owner/repo/rulesets?includes_parents=false' '. + [{id: 2, name: "release"}]'
  jq '.id = 2 | .name = "release"' "$(fixture_path repos/owner/repo/rulesets/1).json" \
    >"$(fixture_path repos/owner/repo/rulesets/2).json"
  run -0 run_sync
  assert_gh_called '--method PUT repos/owner/repo/rulesets/1'
  assert_gh_called '--method PUT repos/owner/repo/rulesets/2'
}

@test "RULESET_FILE applies only the ruleset it names" {
  jq '.name = "release" | .conditions.ref_name.include = ["refs/heads/release"]' \
    "${REPO_COPY}/.github/rulesets/main.json" >"${REPO_COPY}/.github/rulesets/release.json"
  RULESET_FILE="${REPO_COPY}/.github/rulesets/main.json" run -0 run_sync
  assert_gh_called '--method PUT repos/owner/repo/rulesets/1'
  assert_gh_not_called '--method POST repos/owner/repo/rulesets'
}

@test "REPO_SETTINGS=false applies the rulesets only" {
  REPO_SETTINGS=false run -0 run_sync
  assert_gh_called '--method PUT repos/owner/repo/rulesets/1'
  assert_gh_not_called '--method PATCH'
  assert_gh_not_called '--method PUT repos/owner/repo/actions/permissions/workflow'
  grep -q 'github\.com/OWNER/REPO/' "${REPO_COPY}/.github/ISSUE_TEMPLATE/config.yml"
}

@test "rewrites config.yml to the repository name and demands a commit" {
  run -0 run_sync
  grep -q 'github\.com/owner/repo/' "${REPO_COPY}/.github/ISSUE_TEMPLATE/config.yml"
  [[ "${output}" == *'Action required: commit .github/ISSUE_TEMPLATE/config.yml'* ]]
}

@test "leaves a config.yml that carries no placeholder alone" {
  sed 's#OWNER/REPO#owner/repo#' "${REPO_COPY}/.github/ISSUE_TEMPLATE/config.yml" >"${BATS_TEST_TMPDIR}/config.yml"
  cp "${BATS_TEST_TMPDIR}/config.yml" "${REPO_COPY}/.github/ISSUE_TEMPLATE/config.yml"
  run -0 run_sync
  [[ "${output}" != *'Action required'* ]]
}

@test "creates only the labels that are missing" {
  edit_fixture repos/owner/repo/labels 'map(select(.name != "maintenance"))'
  run -0 run_sync
  assert_gh_called '--method POST repos/owner/repo/labels -f name=maintenance'
  assert_gh_not_called '-f name=bug'
}

@test "warns when classic branch protection is still on main" {
  pass_endpoint repos/owner/repo/branches/main/protection
  run -0 run_sync
  [[ "${output}" == *'classic branch protection'* ]]
}

@test "a failure before the first write does not claim a partial application" {
  fail_endpoint repos/owner/repo 1
  run -1 run_sync
  [[ "${output}" != *'Only part of the configuration was applied'* ]]
  assert_gh_not_called '--method'
}

@test "a failure midway reports the partial application and the pending rewrite" {
  fail_endpoint repos/owner/repo/immutable-releases 1
  run -1 run_sync
  [[ "${output}" == *'Only part of the configuration was applied'* ]]
  [[ "${output}" == *'Action required: commit'* ]]
}

@test "a read that fails once everything is applied does not claim a partial application" {
  # Removing the fixture leaves the PUT the apply path sends succeeding (the stub only
  # answers reads from fixtures), so the closing summary is the only thing that fails.
  rm -f "$(fixture_path repos/owner/repo/immutable-releases).json"
  run -1 run_sync
  [[ "${output}" == *'done. current settings:'* ]]
  [[ "${output}" != *'Only part of the configuration was applied'* ]]
}

@test "stops without applying anything when the list of rulesets cannot be fetched" {
  fail_endpoint 'repos/owner/repo/rulesets?includes_parents=false' 1
  run -1 run_sync
  [[ "${output}" == *'could not fetch the list of rulesets'* ]]
  assert_gh_not_called '--method'
  [[ "${output}" != *'Only part of the configuration was applied'* ]]
}
