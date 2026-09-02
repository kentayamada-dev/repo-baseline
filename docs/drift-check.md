# Settings drift check

**English** | [日本語](drift-check.ja.md)

The settings the script in [Setup](../README.md#setup) applies can be changed from the GitHub UI at any time. Either way — whether someone changes them in the UI, or a setting is added to the script and nobody re-runs it — `ci` stays green. So [repo-settings.yml](../.github/workflows/repo-settings.yml) runs `--check` daily (07:00 JST) and on pushes to main, and fails when the current settings have drifted from the definitions. It is a scheduled run rather than a `ci` job because its result changes without any code change ([why such checks are scheduled runs](ci-jobs.md#ci-check-jobs)).

```bash
./scripts/sync-repo-config.sh --check
```

| What it looks at | Verdict |
| --- | --- |
| Repository settings (auto-merge / merge method / squash title / Issues, and so on) | Whether the value matches the definition |
| Immutable releases / private vulnerability reporting / Dependabot alerts | Whether they are enabled |
| Secret scanning push protection | Whether it is enabled |
| Default permissions of the Actions `GITHUB_TOKEN` (fixed to read / creating and approving PRs forbidden) | Whether the value matches the definition |
| Labels (the four in [Labels](../README.md#labels)) | **Whether one with the same name exists** |
| Rulesets (each file in `.github/rulesets/*.json`) | Whether the enforcement, targets, the number of bypass actors, and the contents of every rule match the definition |

For a ruleset, only what the definition names is compared. The API adds fields of its own — `id`, `created_at`, and parameters GitHub introduces later — and treating those as drift would turn every addition on GitHub's side into a failure. Arrays are sorted before the comparison, because the API does not promise to hand back the order they were sent in. A rule the definition does not have is reported as `unexpected rule`, so a rule added in the UI is caught as well.

**For labels it still only checks existence.** A color or description rewritten in the UI is not detected (a rename or deletion is detected as "missing").

The expected values live in `REPO_SETTINGS_EXPECTED` / `REPO_SETTINGS_ENDPOINTS` / `SECURITY_ANALYSIS_EXPECTED` / `ACTIONS_WORKFLOW_EXPECTED` / `LABELS_EXPECTED` in the [script](../scripts/sync-repo-config.sh), and both applying and checking read from there, so fixing one side without the other can never leave them disagreeing. Adding a setting is a single line here, and it is automatically covered by `--check` and `--dry-run`.

On drift, running it without arguments applies the definitions.

```bash
./scripts/sync-repo-config.sh
```

## Notification on failure

**When the check fails, an issue is opened.** A failed scheduled run is otherwise only visible on the Actions page or in a notification email, and missing it means operating with the drift in place.

The issue is titled `Repository settings have drifted` and gets the `maintenance` label ([Labels](../README.md#labels)); the body holds the check output, the run log URL, and how to fix it. While the same issue is already open, the latest check output is commented on it instead of creating another, and once the check passes it closes automatically.

Creating, commenting on, and closing the issue uses the workflow's `GITHUB_TOKEN` (`issues: write`). `SETTINGS_TOKEN` can stay read-only.

The other scheduled workflows report the same way, and their reporting steps share a shape that each file only points at from a comment. A check whose output goes through `tee` sets `pipefail`, because otherwise tee's exit status would hide a failed check. The step that opens the issue also tests `steps.check.outcome`, so that a failure in another step, such as checkout, does not open a bogus issue. Where the reporting is a `notify` job of its own ([osv-scanner](ci-jobs.md#osv-scanner), [Scorecard](ci-jobs.md#scorecard), [Renovate](renovate.md#when-a-run-fails)), that job runs under `!cancelled()` so that it still runs when the job it inspects has failed, checks out the repository because the scripts that do the reporting live in it, and does nothing for a result that is neither success nor failure, such as cancelled.

## About the token

**The default `GITHUB_TOKEN` cannot read everything the check looks at** (the table below says which items need more); those come back as `UNKNOWN`. To run the check from Actions, register a fine-grained PAT as the `SETTINGS_TOKEN` secret. When it is registered, the workflow uses it.

```bash
gh secret set SETTINGS_TOKEN
```

**The merge-related settings are read through GraphQL.** The REST `GET /repos/{owner}/{repo}` omits `allow_*` and `squash_merge_commit_title` from the response without write access (the fields silently disappear rather than producing an error). To check with a read-only token, every repository setting is taken from GraphQL's `Repository`.

| Item | How it is read | Permission needed |
| --- | --- | --- |
| Repository settings (merge-related and so on) | GraphQL `Repository` | read is enough |
| Rulesets (the listing, then each ruleset's contents by id) | REST | read is enough |
| Private vulnerability reporting | REST | read is enough |
| Immutable releases | REST | **Administration: Read-only** |
| Dependabot alerts | REST (a status code with no body: 204 enabled / 404 disabled) | **Administration: Read-only** |
| Secret scanning push protection | REST (`security_and_analysis`) | **Administration: Read-only** |
| Default permissions of the Actions `GITHUB_TOKEN` | REST | **Administration: Read-only** |

For Dependabot alerts, a `404` is also what a token without admin access gets, indistinguishable from "disabled". It is treated as disabled only when the caller has admin access; otherwise it is reported as `UNKNOWN`.

The applying side (running without arguments) uses REST `PATCH`. That is not a problem because the person running it locally has admin access.

**"Drifted from the definition" and "cannot be checked for lack of permissions" are reported separately** because the fixes differ. The fix for the former is running the script without arguments; for the latter, changing the token.

```text
  OK      allow_auto_merge = true
  DRIFT   squash_merge_commit_title = COMMIT_OR_PR_TITLE (expected: PR_TITLE)
  DRIFT   ruleset main: rule required_linear_history is missing
  UNKNOWN immutable-releases (cannot be fetched)
```

### Creating `SETTINGS_TOKEN`

The token to issue is a fine-grained PAT. There is no API for issuing a PAT, so create it in the browser.

1. Open [Settings > Developer settings > Personal access tokens > Fine-grained tokens](https://github.com/settings/personal-access-tokens/new)
2. Create it with the following

    | Item | Value |
    | --- | --- |
    | Token name | A name that says what it is for, such as `repo-settings (OWNER/REPO)` |
    | Resource owner | The repository owner (for an Organization, approval on the organization side may be required) |
    | Expiration | Whatever suits how you operate. Once it expires the check fails with "UNKNOWN" and opens an issue |
    | Repository access | Only select repositories → the target repository |

3. Under Repository permissions grant only `Administration: Read-only` (`Metadata: Read-only` is added automatically). **No write permission is needed at all.** This workflow only reads; applying settings is done by running the script locally.

4. Copy the token that is shown and register it as a secret (paste the value at the prompt)

    ```bash
    gh secret set SETTINGS_TOKEN
    ```

5. Run it for real to confirm

    ```bash
    gh workflow run repo-settings.yml
    gh run watch
    ```

The mapping between GitHub permissions and response fields is undocumented, so if "UNKNOWN" persists, revisit this permission (the check output says what could not be read).
