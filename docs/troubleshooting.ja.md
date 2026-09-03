# トラブルシューティング

[English](troubleshooting.md) | **日本語**

CI のジョブが落ちた場合は、[CI の検査ジョブ](ci-jobs.ja.md#ci-の検査ジョブ)の表から該当する節を引いてください。

## PR が「必須チェック待ち」で止まる

`ci` という名前のチェックが、期待した報告元から届いていません。ワークフローに `paths` フィルタが付いていないか、ジョブ名が `ci` から変わっていないかを確認します。

Actions は緑なのに待ち続ける場合は、[main.json](../.github/rulesets/main.json) の `integration_id` が実際の報告元と食い違っています。次のコマンドで `ci` の行の `app.id` を確認し、JSON に反映してスクリプトを再実行してください。

```bash
gh api repos/OWNER/REPO/commits/main/check-runs --jq '.check_runs[] | "\(.name)\t\(.app.id)\t\(.app.slug)"'
```

## CI は緑なのにマージできない

必須チェック以外に、マージを止める保護が 2 つあります（[ブランチ保護の内容](../README.ja.md#ブランチ保護の内容)）。

- 未解決のレビューコメント。Files changed タブで、自分の PR に自分で付けたものも含めてすべて resolve してください。
- Code scanning のアラート（重大度は問いません）。Security タブの Code scanning を開き、直すか dismiss してください（[CodeQL](ci-jobs.ja.md#codeql)）。

## Renovate の PR が作られない

`renovate` ワークフローが失敗しているなら、原因はほぼ `RENOVATE_TOKEN` です（[実行が失敗したとき](renovate.ja.md#実行が失敗したとき)）。成功しているなら、`Dependency updates are available` の issue が立っていない限り更新は無かったということです（[更新の一覧の issue](renovate.ja.md#更新の一覧の-issue)）。

## 定期実行のワークフローが動かない

Actions タブで、GitHub がそのワークフローの schedule を止めていないかを確認してください（[定期実行が止まるとき](ci-jobs.ja.md#定期実行が止まるとき)）。

osv-scanner が実行されているのに何も検出されない場合は、[検査対象が無いときは黙って通ります](ci-jobs.ja.md#検査対象が無いときは黙って通ります)を見てください。

## PR に灰色の `osv-scanner` が出る

`1 configuration not found` という警告です。正常な状態で、マージも止まりません。理由と、消さずに残している理由は [PR に出る「1 configuration not found」](ci-jobs.ja.md#pr-に出る1-configuration-not-found)にあります。

## CI が壊れて main を直せない

[main.json](../.github/rulesets/main.json) の `enforcement` を `disabled` にしてスクリプトを再実行すれば一時的に保護を外せます。復旧後に `active` へ戻してください。
