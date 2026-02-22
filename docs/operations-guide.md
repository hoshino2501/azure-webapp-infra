# 運用手順書

## 目次

1. [日常運用タスク](#1-日常運用タスク)
   - 1.1 [ログの確認](#11-ログの確認)
   - 1.2 [リソースの稼働確認](#12-リソースの稼働確認)
2. [デプロイ運用](#2-デプロイ運用)
   - 2.1 [通常のアプリケーション更新](#21-通常のアプリケーション更新)
   - 2.2 [インフラ変更のデプロイ](#22-インフラ変更のデプロイ)
   - 2.3 [ロールバック手順](#23-ロールバック手順)
3. [シークレット・証明書の管理](#3-シークレット証明書の管理)
   - 3.1 [DB パスワードのローテーション](#31-db-パスワードのローテーション)
   - 3.2 [Entra ID クライアントシークレットの更新](#32-entra-id-クライアントシークレットの更新)
4. [スケーリング](#4-スケーリング)
   - 4.1 [App Service のスケールアップ/ダウン](#41-app-service-のスケールアップダウン)
   - 4.2 [PostgreSQL のスケールアップ](#42-postgresql-のスケールアップ)
5. [バックアップとリストア](#5-バックアップとリストア)
   - 5.1 [PostgreSQL バックアップの確認](#51-postgresql-バックアップの確認)
   - 5.2 [PostgreSQL のポイントインタイムリストア](#52-postgresql-のポイントインタイムリストア)
6. [障害対応](#6-障害対応)
   - 6.1 [App Service が応答しない](#61-app-service-が応答しない)
   - 6.2 [PostgreSQL に接続できない](#62-postgresql-に接続できない)
   - 6.3 [Key Vault にアクセスできない](#63-key-vault-にアクセスできない)
7. [セキュリティ運用](#7-セキュリティ運用)
   - 7.1 [Key Vault 監査ログの確認](#71-key-vault-監査ログの確認)
   - 7.2 [不審なアクセスの調査](#72-不審なアクセスの調査)
8. [コスト管理](#8-コスト管理)
9. [定期メンテナンスチェックリスト](#9-定期メンテナンスチェックリスト)

---

## 1. 日常運用タスク

### 1.1 ログの確認

Log Analytics ワークスペース (`log-<env>`) に全コンポーネントのログが集約されています。

#### Azure Portal からの確認

1. **Azure Portal** > **Log Analytics ワークスペース** > `log-<env>` > **ログ** を開く
2. 以下の KQL クエリを使用する

#### よく使うクエリ

```kusto
// App Service への HTTP リクエスト（直近1時間・エラーのみ）
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| where ScStatus >= 400
| project TimeGenerated, CsHost, CsUriStem, ScStatus, TimeTaken
| order by TimeGenerated desc

// App Service アプリケーションログ（直近30分）
AppServiceAppLogs
| where TimeGenerated > ago(30m)
| project TimeGenerated, Level, Message
| order by TimeGenerated desc

// PostgreSQL エラーログ
AzureDiagnostics
| where ResourceType == "FLEXIBLESERVERS"
| where Category == "PostgreSQLLogs"
| where TimeGenerated > ago(1h)
| where Message contains "ERROR"
| project TimeGenerated, Message
| order by TimeGenerated desc

// Key Vault 操作ログ（直近24時間）
AzureDiagnostics
| where ResourceType == "VAULTS"
| where TimeGenerated > ago(24h)
| project TimeGenerated, OperationName, ResultType, CallerIPAddress, identity_claim_upn_s
| order by TimeGenerated desc
```

#### Azure CLI からの確認

```bash
# App Service のログストリームをリアルタイム表示
az webapp log tail \
  --name "app-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>"

# App Service のログをダウンロード
az webapp log download \
  --name "app-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>" \
  --log-file ./app-logs.zip
```

---

### 1.2 リソースの稼働確認

```bash
# App Service の状態確認
az webapp show \
  --name "app-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>" \
  --query "{state:state,availabilityState:availabilityState,httpsOnly:httpsOnly}"

# PostgreSQL の状態確認
az postgres flexible-server show \
  --name "psql-<env>" \
  --resource-group "rg-<project>-<env>" \
  --query "{state:state,availabilityZone:availabilityZone,fullyQualifiedDomainName:fullyQualifiedDomainName}"

# Key Vault の状態確認
az keyvault show \
  --name "kv-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>" \
  --query "{provisioningState:properties.provisioningState,publicNetworkAccess:properties.publicNetworkAccess}"
```

---

## 2. デプロイ運用

### 2.1 通常のアプリケーション更新

アプリケーションコード（Docker イメージ）の更新は、`terraform.tfvars` の `docker_image_name` を変更して CI/CD 経由でデプロイします。

```bash
# 例: environments/prod/terraform.tfvars
docker_image_name = "myregistry.azurecr.io/myapp:v1.2.3"  # 新バージョンに変更
```

**デプロイフロー:**

1. フィーチャーブランチで `docker_image_name` を更新し、コミット・プッシュ
2. `main` ブランチへの Pull Request を作成
3. GitHub Actions が `terraform plan` を実行し、PR にプラン差分をコメント
4. 変更内容を確認後、PR をマージ
5. GitHub Actions が `terraform apply` を自動実行

> **デプロイ順序:** `dev` → `staging` → `prod` の順にマージ・確認することを推奨します。

---

### 2.2 インフラ変更のデプロイ

Terraform コードの変更（リソース設定の変更など）も同じ CI/CD フローで適用されます。

**変更前の注意事項:**

- `terraform plan` の出力で `destroy` が含まれる変更は特に慎重に確認する
- PostgreSQL や Key Vault の再作成が発生する変更は、データ損失につながるため prod 環境では事前にバックアップを確認する
- prod 環境への適用前に必ず `dev` / `staging` 環境で動作確認する

**ローカルでのプラン確認:**

```bash
cd environments/<env>
az login
az account set --subscription "<SUBSCRIPTION_ID>"

export TF_VAR_db_password="<password>"

terraform init
terraform plan -out=tfplan

# 変更内容を詳細確認
terraform show tfplan
```

---

### 2.3 ロールバック手順

#### アプリケーションのロールバック

`docker_image_name` を前のバージョンに戻してデプロイします。

```bash
# environments/<env>/terraform.tfvars を編集
docker_image_name = "myregistry.azurecr.io/myapp:v1.2.2"  # 前バージョンに戻す
```

PR を作成 → マージ → 自動 apply でロールバックされます。

#### 緊急時のロールバック（ローカルから直接適用）

```bash
cd environments/<env>
export TF_VAR_db_password="<password>"

# 直前の tfstate に対応するコードに戻す (git revert など)
git revert HEAD

terraform plan
terraform apply
```

#### tfstate のロールバック（最終手段）

tfstate が破損・不整合になった場合は Blob Storage のバージョン履歴から復元します。

1. Azure Portal で tfstate ストレージアカウントを開く
2. **コンテナ** > `tfstate` > 対象の `.tfstate` ファイルを選択
3. **バージョン** タブから以前のバージョンを選択し **昇格** または **ダウンロード** して上書き

---

## 3. シークレット・証明書の管理

### 3.1 DB パスワードのローテーション

1. **新しいパスワードを生成する**（英数字・記号混在、16 文字以上推奨）

2. **GitHub シークレットを更新する**

   ```bash
   gh secret set TF_VAR_DB_PASSWORD --body "<新しいパスワード>"
   ```

3. **Key Vault のシークレットを更新する**

   ```bash
   az keyvault secret set \
     --vault-name "kv-<env>-<suffix>" \
     --name "db-password" \
     --value "<新しいパスワード>"
   ```

4. **PostgreSQL のパスワードを更新する**

   ```bash
   az postgres flexible-server update \
     --name "psql-<env>" \
     --resource-group "rg-<project>-<env>" \
     --admin-password "<新しいパスワード>"
   ```

5. **App Service を再起動して新しい接続文字列を反映させる**

   ```bash
   az webapp restart \
     --name "app-<env>-<suffix>" \
     --resource-group "rg-<project>-<env>"
   ```

6. **動作確認後、Terraform の tfstate との整合性を保つため `terraform apply` を実行する**

   > `TF_VAR_db_password` を更新した後に apply することで、Terraform 管理下のパスワードと実際のパスワードが一致します。

---

### 3.2 Entra ID クライアントシークレットの更新

Entra ID のクライアントシークレットには有効期限があります（dev/staging: 2026-12-31、prod: 2027-12-31）。期限切れ前に更新してください。

#### 更新手順

1. **現在のシークレット期限を確認する**

   ```bash
   cd environments/<env>
   terraform output -raw entra_client_secret_expiry
   ```

2. **`terraform.tfvars` のシークレット期限を延長する**

   ```hcl
   # environments/<env>/terraform.tfvars
   entra_client_secret_expiry = "2028-12-31"  # 新しい期限に変更
   ```

3. **PR を作成して CI/CD 経由で `terraform apply` を実行する**

   apply 完了後、新しいクライアントシークレットが Key Vault に保存されます。

4. **App Service の認証設定を更新する**（[setup-guide.md の 6.2](./setup-guide.md#62-app-service-認証の設定) を参照）

   新しいシークレットを App Service の認証プロバイダー設定に反映させます。

   ```bash
   # 新しいシークレット値を確認
   cd environments/<env>
   terraform output -raw entra_client_secret
   ```

---

## 4. スケーリング

### 4.1 App Service のスケールアップ/ダウン

`terraform.tfvars` の SKU を変更して CI/CD 経由で適用します。

```hcl
# environments/prod/terraform.tfvars
app_service_sku_name = "P3v3"  # P2v3 から変更
```

| SKU | vCPU | RAM | 用途目安 |
|---|---|---|---|
| B1 | 1 | 1.75 GB | 開発・テスト |
| P1v3 | 1 | 4 GB | 小規模本番 |
| P2v3 | 2 | 8 GB | 中規模本番 |
| P3v3 | 4 | 16 GB | 大規模本番 |

> **注意:** SKU 変更は数分のダウンタイムが発生する場合があります。メンテナンス時間帯に実施することを推奨します。

---

### 4.2 PostgreSQL のスケールアップ

`terraform.tfvars` の SKU とストレージサイズを変更して適用します。

```hcl
# environments/prod/terraform.tfvars
postgresql_sku_name    = "GP_Standard_D8s_v3"  # D4s_v3 から変更
postgresql_storage_mb  = 262144                 # 128 GB → 256 GB
```

> **重要:** PostgreSQL のストレージサイズは**縮小できません**。増量のみ可能です。

> **注意:** SKU 変更時は数分のダウンタイムが発生します。prod 環境ではメンテナンス時間帯に実施してください。

---

## 5. バックアップとリストア

### 5.1 PostgreSQL バックアップの確認

Azure Database for PostgreSQL フレキシブルサーバーは自動バックアップが有効です。

```bash
# バックアップ保持期間の確認
az postgres flexible-server show \
  --name "psql-<env>" \
  --resource-group "rg-<project>-<env>" \
  --query "backup"

# バックアップ一覧の確認
az postgres flexible-server backup list \
  --name "psql-<env>" \
  --resource-group "rg-<project>-<env>"
```

| 環境 | 保持期間 | geo 冗長バックアップ |
|---|---|---|
| dev | 7 日 | 無効 |
| staging | 14 日 | 無効 |
| prod | 35 日 | **有効** |

---

### 5.2 PostgreSQL のポイントインタイムリストア

> **注意:** リストアは既存サーバーへの上書きではなく、**新しいサーバーとして作成**されます。リストア後にアプリケーションの接続先を切り替える作業が必要です。

```bash
# ポイントインタイムリストア（CLI）
az postgres flexible-server restore \
  --name "psql-<env>-restored" \
  --resource-group "rg-<project>-<env>" \
  --source-server "psql-<env>" \
  --restore-time "2024-01-15T03:00:00Z"  # UTC で指定
```

**リストア後の作業:**

1. リストアされたサーバーの FQDN を確認する
2. `terraform.tfvars` の PostgreSQL 関連設定を更新する、または App Service の `DATABASE_URL` 環境変数を一時的に変更する
3. データ整合性を確認する
4. 問題がなければ元のサーバーを削除し、Terraform の tfstate を更新する

---

## 6. 障害対応

### 6.1 App Service が応答しない

**確認手順:**

```bash
# 1. App Service の状態確認
az webapp show \
  --name "app-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>" \
  --query "{state:state}"

# 2. ログを確認
az webapp log tail \
  --name "app-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>"
```

**Log Analytics でのエラー調査:**

```kusto
// 直近15分のエラーログ
AppServiceConsoleLogs
| where TimeGenerated > ago(15m)
| where Level in ("Error", "Critical")
| project TimeGenerated, Level, ResultDescription
| order by TimeGenerated desc
```

**復旧手順:**

```bash
# App Service を再起動
az webapp restart \
  --name "app-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>"

# デプロイスロットがある場合はスワップでロールバック
az webapp deployment slot swap \
  --name "app-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>" \
  --slot staging \
  --target-slot production
```

---

### 6.2 PostgreSQL に接続できない

**確認手順:**

```bash
# 1. PostgreSQL サーバーの状態確認
az postgres flexible-server show \
  --name "psql-<env>" \
  --resource-group "rg-<project>-<env>" \
  --query "{state:state}"

# 2. App Service の環境変数 DATABASE_URL を確認
az webapp config appsettings list \
  --name "app-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>" \
  --query "[?name=='DATABASE_URL']"
```

**VNet 接続の確認:**

App Service の **SSH コンソール** (https://`app-<env>-<suffix>`.scm.azurewebsites.net/webssh/host) から接続テスト:

```bash
# DNS 解決確認
nslookup psql-<env>.postgres.database.azure.com

# 接続確認
pg_isready -h psql-<env>.postgres.database.azure.com -U pgadmin
```

**よくある原因と対処:**

| 原因 | 対処 |
|---|---|
| PostgreSQL サーバーが停止中 | Azure Portal または CLI で起動する |
| Private DNS Zone の VNet リンクが切れている | `modules/networking` を再 apply する |
| パスワードが一致しない | [3.1 DB パスワードのローテーション](#31-db-パスワードのローテーション) を参照 |

---

### 6.3 Key Vault にアクセスできない

**確認手順:**

```bash
# Managed Identity のオブジェクト ID を確認
PRINCIPAL_ID=$(az webapp identity show \
  --name "app-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>" \
  --query principalId --output tsv)

# RBAC ロール割り当てを確認
az role assignment list \
  --assignee "${PRINCIPAL_ID}" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-<project>-<env>/providers/Microsoft.KeyVault/vaults/kv-<env>-<suffix>" \
  --query "[].{role:roleDefinitionName,scope:scope}"
```

**Key Vault 監査ログでのエラー確認:**

```kusto
AzureDiagnostics
| where ResourceType == "VAULTS"
| where ResultType != "Success"
| where TimeGenerated > ago(1h)
| project TimeGenerated, OperationName, ResultType, ResultDescription, CallerIPAddress
| order by TimeGenerated desc
```

**対処:**

```bash
# Key Vault Secrets User ロールを再付与
az role assignment create \
  --assignee "${PRINCIPAL_ID}" \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-<project>-<env>/providers/Microsoft.KeyVault/vaults/kv-<env>-<suffix>"
```

> ロール付与後、反映まで最大 5 分かかります。

---

## 7. セキュリティ運用

### 7.1 Key Vault 監査ログの確認

定期的（月1回以上推奨）に Key Vault へのアクセスを監査します。

```kusto
// 過去30日間の Key Vault 操作一覧
AzureDiagnostics
| where ResourceType == "VAULTS"
| where TimeGenerated > ago(30d)
| summarize count() by OperationName, ResultType, bin(TimeGenerated, 1d)
| order by TimeGenerated desc

// 失敗した操作の一覧
AzureDiagnostics
| where ResourceType == "VAULTS"
| where ResultType != "Success"
| where TimeGenerated > ago(30d)
| project TimeGenerated, OperationName, ResultType, CallerIPAddress, identity_claim_upn_s
| order by TimeGenerated desc
```

---

### 7.2 不審なアクセスの調査

```kusto
// 通常と異なる IP アドレスからのアクセス
AppServiceHTTPLogs
| where TimeGenerated > ago(7d)
| summarize RequestCount = count() by CIp
| order by RequestCount desc

// 認証エラーの集計（Entra ID 認証失敗）
AppServiceHTTPLogs
| where TimeGenerated > ago(24h)
| where ScStatus == 401 or ScStatus == 403
| summarize count() by CIp, CsUriStem
| order by count_ desc
```

**不審なアクセスを検知した場合:**

1. 該当 IP を App Service のアクセス制限に追加する（Azure Portal > App Service > ネットワーク > アクセス制限）
2. Key Vault の監査ログで同 IP からのアクセスがないか確認する
3. 必要に応じてシークレットをローテーションする

---

## 8. コスト管理

### コスト確認

```bash
# リソースグループごとのコスト確認（Azure CLI）
az consumption usage list \
  --billing-period-name "202501" \
  --query "[?contains(instanceId, 'rg-<project>')]" \
  --output table
```

### コスト最適化のポイント

| 環境 | 推奨事項 |
|---|---|
| dev | 業務時間外に App Service・PostgreSQL を停止する |
| staging | 継続的な負荷テストが不要な期間は B1/B_Standard_B1ms に縮小する |
| prod | Reserved Instances の購入を検討する（1年/3年契約で最大 72% 削減） |

#### dev 環境の自動停止（コスト削減）

```bash
# App Service を停止
az webapp stop \
  --name "app-dev-<suffix>" \
  --resource-group "rg-<project>-dev"

# App Service を起動
az webapp start \
  --name "app-dev-<suffix>" \
  --resource-group "rg-<project>-dev"

# PostgreSQL を停止（最大7日間停止可能）
az postgres flexible-server stop \
  --name "psql-dev" \
  --resource-group "rg-<project>-dev"

# PostgreSQL を起動
az postgres flexible-server start \
  --name "psql-dev" \
  --resource-group "rg-<project>-dev"
```

> **注意:** PostgreSQL フレキシブルサーバーは停止後 7 日で自動的に再起動されます。

---

## 9. 定期メンテナンスチェックリスト

### 毎週

- [ ] Log Analytics でエラーログを確認する
- [ ] App Service の CPU・メモリ使用率を確認する
- [ ] PostgreSQL のストレージ使用量を確認する（上限の 80% を超えたらスケールアップを検討）

### 毎月

- [ ] Key Vault 監査ログを確認し、不審なアクセスがないか確認する
- [ ] GitHub Actions のワークフロー実行履歴を確認する
- [ ] コストレポートを確認し、想定外の費用増加がないか確認する
- [ ] Terraform のバージョンを確認し、アップグレードが必要か検討する

### 四半期ごと

- [ ] Entra ID クライアントシークレットの有効期限を確認し、期限 3 ヶ月前までに更新する
- [ ] DB パスワードをローテーションする
- [ ] Azure プロバイダーの新しいリリースを確認し、`required_providers` のバージョン更新を検討する
- [ ] セキュリティアドバイザリを確認し、必要なパッチを適用する
- [ ] PostgreSQL メジャーバージョンのサポート状況を確認する

### 年次

- [ ] Azure サブスクリプションの使用量クォータを確認する
- [ ] Reserved Instances の購入・更新を検討する
- [ ] 障害対応訓練（ポイントインタイムリストアの実施など）
- [ ] アーキテクチャの見直し（新機能・サービスへの移行検討）
