# Troubleshooting

**English** | [日本語](troubleshooting.ja.md)

When a CI job fails, look up the relevant section from the table in [CI check jobs](ci-jobs.md#ci-check-jobs).

## A PR is stuck waiting for a required check

The check named `ci` has not arrived from the expected reporter. Check whether a `paths` filter was added to the workflow, or whether the job name changed from `ci`.

If Actions is green but it keeps waiting, the `integration_id` in [main.json](../.github/rulesets/main.json) disagrees with the actual reporter. Check the `app.id` on the `ci` row with the following command, update the JSON to match, and run the script again.

```bash
gh api repos/OWNER/REPO/commits/main/check-runs --jq '.check_runs[] | "\(.name)\t\(.app.id)\t\(.app.slug)"'
```

## A merge is blocked while CI is green

Two protections other than the required check can hold the merge button ([What branch protection enforces](../README.md#what-branch-protection-enforces)).

- An unresolved review thread. Resolve every thread on the Files changed tab, including the ones you left on your own PR.
- A Code scanning alert, whatever its severity. Open Code scanning on the Security tab and either fix the alert or dismiss it ([CodeQL](ci-jobs.md#codeql)).

## Renovate does not create PRs

If the `renovate` workflow failed, the cause is almost always `RENOVATE_TOKEN` ([When a run fails](renovate.md#when-a-run-fails)). If it succeeded, there was nothing to update unless the `Dependency updates are available` issue is open ([The update list issue](renovate.md#the-update-list-issue)).

## A scheduled workflow does not run

Check on the Actions tab whether GitHub has disabled the workflow's schedule ([When the scheduled run stops](ci-jobs.md#when-the-scheduled-run-stops)).

If osv-scanner runs but detects nothing, see [It passes silently when there is nothing to scan](ci-jobs.md#it-passes-silently-when-there-is-nothing-to-scan).

## A greyed-out `osv-scanner` appears on the PR

That is the `1 configuration not found` warning. It is normal and does not block the merge. The reason for it, and the reason it is left in place, are in [The "1 configuration not found" shown on PRs](ci-jobs.md#the-1-configuration-not-found-shown-on-prs).

## CI is broken and main cannot be fixed

Setting `enforcement` in [main.json](../.github/rulesets/main.json) to `disabled` and running the script again lifts the protection temporarily. Set it back to `active` once things are restored.
