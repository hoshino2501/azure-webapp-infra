# インフラ構築手順書

## 目次

1. [前提条件・必要ツール](#1-前提条件必要ツール)
2. [Azure 事前設定](#2-azure-事前設定)
   - 2.1 [リソースプロバイダーの登録](#21-リソースプロバイダーの登録)
   - 2.2 [tfstate 管理用ストレージアカウントの作成](#22-tfstate-管理用ストレージアカウントの作成)
   - 2.3 [GitHub Actions 用サービスプリンシパル・OIDC の設定](#23-github-actions-用サービスプリンシパルoidc-の設定)
3. [GitHub 事前設定](#3-github-事前設定)
   - 3.1 [リポジトリのシークレット登録](#31-リポジトリのシークレット登録)
   - 3.2 [GitHub Environments の設定](#32-github-environments-の設定)
4. [Terraform コードの設定](#4-terraform-コードの設定)
   - 4.1 [backend の storage_account_name を埋める](#41-backend-の-storage_account_name-を埋める)
   - 4.2 [terraform.tfvars の値を設定する](#42-terraformtfvars-の値を設定する)
5. [初回デプロイ](#5-初回デプロイ)
   - 5.1 [ローカルからの手動適用（初回のみ）](#51-ローカルからの手動適用初回のみ)
   - 5.2 [CI/CD 経由でのデプロイ](#52-cicd-経由でのデプロイ)
6. [Terraform 適用後の手動設定](#6-terraform-適用後の手動設定)
   - 6.1 [Entra ID API アクセス許可への管理者同意](#61-entra-id-api-アクセス許可への管理者同意)
   - 6.2 [App Service 認証の設定](#62-app-service-認証の設定)
7. [動作確認](#7-動作確認)
8. [トラブルシューティング](#8-トラブルシューティング)

---

## 1. 前提条件・必要ツール

### 必要なツール

| ツール | バージョン | インストール方法 |
|---|---|---|
| Terraform | >= 1.9 | [公式サイト](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | 最新版 | `brew install azure-cli` (macOS) / [公式ドキュメント](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli) |
| Git | 最新版 | `brew install git` (macOS) |

### 前提条件

- Azure サブスクリプションが作成済みであること
- Azure Entra ID に**グローバル管理者**または**アプリケーション管理者**権限を持つアカウントでサインインできること
- Azure サブスクリプションに対して**所有者 (Owner)** ロールを持つアカウントでサインインできること
- GitHub アカウントおよびリポジトリが存在すること

---

## 2. Azure 事前設定

### 2.1 リソースプロバイダーの登録

Azure サブスクリプション作成直後は一部のリソースプロバイダーが未登録の場合があります。以下のコマンドで必要なプロバイダーを登録します。

```bash
# Azure CLI でログイン
az login

# 使用するサブスクリプションを確認・設定
az account list --output table
az account set --subscription "<サブスクリプション名またはID>"

# 必要なリソースプロバイダーを登録
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.DBforPostgreSQL
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage

# 登録状態の確認（Registered と表示されるまで待機）
az provider show --namespace Microsoft.Web --query registrationState
az provider show --namespace Microsoft.DBforPostgreSQL --query registrationState
az provider show --namespace Microsoft.KeyVault --query registrationState
```

> **注意:** プロバイダーの登録には数分かかる場合があります。`Registered` と表示されるまで待ってから次のステップに進んでください。

---

### 2.2 tfstate 管理用ストレージアカウントの作成

Terraform の状態ファイル (tfstate) を Azure Blob Storage で管理するため、専用のストレージアカウントを作成します。

> **注意:** このストレージアカウントは Terraform 管理外 (手動作成) です。誤って削除しないよう注意してください。

```bash
# 変数を設定（実際の値に変更してください）
LOCATION="japaneast"
RG_TFSTATE="rg-tfstate"
# ストレージアカウント名はグローバル一意かつ 3〜24 文字の英数字小文字
STORAGE_ACCOUNT_NAME="tfstate<任意のサフィックス>"  # 例: tfstatemywebapp001

# リソースグループを作成
az group create \
  --name "${RG_TFSTATE}" \
  --location "${LOCATION}"

# ストレージアカウントを作成
az storage account create \
  --name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RG_TFSTATE}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

# Blob コンテナを作成
az storage container create \
  --name "tfstate" \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --auth-mode login

# ストレージアカウント名を控えておく（後の手順で使用）
echo "Storage Account Name: ${STORAGE_ACCOUNT_NAME}"
```

---

### 2.3 GitHub Actions 用サービスプリンシパル・OIDC の設定

GitHub Actions から Azure へパスワードレスで認証するため、OIDC (Federated Credentials) を使用するサービスプリンシパルを作成します。

#### サービスプリンシパルの作成

```bash
# サブスクリプション ID を取得
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Subscription ID: ${SUBSCRIPTION_ID}"

# テナント ID を取得（後の手順でも使用）
TENANT_ID=$(az account show --query tenantId --output tsv)
echo "Tenant ID: ${TENANT_ID}"

# サービスプリンシパルを作成（Contributor ロール）
# <GITHUB_ORG> と <REPO_NAME> を実際の値に変更してください
SP=$(az ad sp create-for-rbac \
  --name "sp-github-actions-terraform" \
  --role "Contributor" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
  --json-auth)

# クライアント ID を取得
CLIENT_ID=$(echo $SP | jq -r '.clientId')
echo "Client ID: ${CLIENT_ID}"
```

> **重要:** `az ad sp create-for-rbac` で出力されたクライアントシークレットは **この時点でのみ**表示されます。OIDC を使用する場合はシークレットは不要ですが、出力を安全な場所に一時的に保管してください。

#### tfstate ストレージへのアクセス権付与

サービスプリンシパルに対して tfstate ストレージアカウントへの Blob アクセス権を付与します。

```bash
# Storage Blob Data Contributor ロールを付与
az role assignment create \
  --assignee "${CLIENT_ID}" \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_TFSTATE}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT_NAME}"
```

#### OIDC Federated Credentials の設定

GitHub Actions の各ジョブ (main ブランチへの push と PR) に対してフェデレーション認証を設定します。

```bash
# アプリケーション (オブジェクト) ID を取得
APP_OBJECT_ID=$(az ad app list --display-name "sp-github-actions-terraform" --query '[0].id' --output tsv)

# <GITHUB_ORG> と <REPO_NAME> を実際の値に変更してください
GITHUB_ORG="<GITHUB_ORG>"
REPO_NAME="<REPO_NAME>"

# main ブランチへの push 用
az ad app federated-credential create \
  --id "${APP_OBJECT_ID}" \
  --parameters "{
    \"name\": \"github-main-push\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${REPO_NAME}:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Pull Request 用
az ad app federated-credential create \
  --id "${APP_OBJECT_ID}" \
  --parameters "{
    \"name\": \"github-pull-request\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${REPO_NAME}:pull_request\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
```

> **補足:** GitHub Environments を使用している場合 (後述の [3.2](#32-github-environments-の設定) 参照)、Environment ごとに追加でフェデレーション認証が必要です。

```bash
# dev 環境用（GitHub Environment 名を "dev" とした場合）
az ad app federated-credential create \
  --id "${APP_OBJECT_ID}" \
  --parameters "{
    \"name\": \"github-env-dev\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${REPO_NAME}:environment:dev\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# staging 環境用
az ad app federated-credential create \
  --id "${APP_OBJECT_ID}" \
  --parameters "{
    \"name\": \"github-env-staging\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${REPO_NAME}:environment:staging\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# prod 環境用
az ad app federated-credential create \
  --id "${APP_OBJECT_ID}" \
  --parameters "{
    \"name\": \"github-env-prod\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${REPO_NAME}:environment:prod\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
```

---

## 3. GitHub 事前設定

### 3.1 リポジトリのシークレット登録

GitHub リポジトリの **Settings > Secrets and variables > Actions** から以下のシークレットを登録します。

| シークレット名 | 値 | 取得方法 |
|---|---|---|
| `AZURE_CLIENT_ID` | サービスプリンシパルのクライアント ID | `echo $CLIENT_ID` (2.3 の手順) |
| `AZURE_TENANT_ID` | Azure テナント ID | `echo $TENANT_ID` (2.3 の手順) |
| `AZURE_SUBSCRIPTION_ID` | Azure サブスクリプション ID | `echo $SUBSCRIPTION_ID` (2.3 の手順) |
| `TF_VAR_DB_PASSWORD` | PostgreSQL 管理者パスワード | 任意の強力なパスワード（英数字・記号混在、16 文字以上を推奨） |

**GitHub CLI を使って登録する場合:**

```bash
gh secret set AZURE_CLIENT_ID --body "<CLIENT_ID>"
gh secret set AZURE_TENANT_ID --body "<TENANT_ID>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<SUBSCRIPTION_ID>"
gh secret set TF_VAR_DB_PASSWORD --body "<DB_PASSWORD>"
```

---

### 3.2 GitHub Environments の設定

`terraform-apply.yml` では `environment:` ディレクティブを使用し、環境ごとのデプロイゲートを設定できます。GitHub リポジトリの **Settings > Environments** から以下の 3 環境を作成します。

| 環境名 | 推奨設定 |
|---|---|
| `dev` | 保護ルールなし（自動デプロイ可） |
| `staging` | Required reviewers: 任意のレビュワーを設定 |
| `prod` | Required reviewers: 本番デプロイ承認者を設定 |

> **prod 環境では必ず `Required reviewers` を設定し、意図しない本番デプロイを防いでください。**

---

## 4. Terraform コードの設定

### 4.1 backend の storage_account_name を埋める

各環境の `main.tf` にある `backend "azurerm"` ブロックの `storage_account_name` を、[2.2 で作成したストレージアカウント名](#22-tfstate-管理用ストレージアカウントの作成)に変更します。

```bash
# 対象ファイル
# environments/dev/main.tf
# environments/staging/main.tf
# environments/prod/main.tf
```

各ファイルの以下の箇所を編集します:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-tfstate"
  storage_account_name = "tfstate<任意のサフィックス>"  # ← ここを埋める
  container_name       = "tfstate"
  key                  = "dev/terraform.tfstate"        # 環境ごとに異なる
}
```

---

### 4.2 terraform.tfvars の値を設定する

各環境の `terraform.tfvars` を確認し、プロジェクト固有の値を設定します。

#### 共通で変更が必要な値

| 変数名 | 説明 | 変更例 |
|---|---|---|
| `project_name` | プロジェクト名（リソース命名に使用） | `"mywebapp"` → `"yourproject"` |
| `suffix` | グローバル一意リソース名のサフィックス | `"dev001"` → 任意の短い文字列 |
| `entra_tenant_id` | Azure テナント ID | `"<YOUR_TENANT_ID>"` → 実際のテナント ID |
| `docker_image_name` | デプロイするコンテナイメージ | `"nginx:latest"` → 実際のアプリイメージ |
| `docker_registry_url` | コンテナレジストリの URL | ACR 使用時は `"https://<registryname>.azurecr.io"` |

#### テナント ID の確認方法

```bash
az account show --query tenantId --output tsv
```

#### 機密情報は環境変数で設定

`db_password` などの機密情報は `terraform.tfvars` に記載せず、環境変数で設定します。

```bash
# ローカル実行時
export TF_VAR_db_password="<安全なパスワード>"

# コンテナレジストリ認証が必要な場合
export TF_VAR_docker_registry_username="<ユーザー名>"
export TF_VAR_docker_registry_password="<パスワード>"
```

> **注意:** `.gitignore` によって `*.tfvars.json` と `terraform.tfvars` のシークレット記載は除外されていますが、`terraform.tfvars` は Git 管理対象です。**機密情報を `terraform.tfvars` に直接書き込まないでください。**

---

## 5. 初回デプロイ

### 5.1 ローカルからの手動適用（初回のみ）

初回は CI/CD のセットアップが完了していない状態のため、ローカルから直接 `terraform apply` を実行します。

```bash
# Azure CLI でログイン（ローカルからの実行時）
az login
az account set --subscription "<サブスクリプション名またはID>"

# dev 環境から開始
cd environments/dev

# Terraform を初期化
terraform init

# 実行計画を確認
terraform plan

# 適用（確認プロンプトが表示される）
terraform apply
```

> **デプロイ順序:** `dev` → `staging` → `prod` の順に適用することを推奨します。

```bash
# staging 環境
cd ../staging
terraform init
terraform plan
terraform apply

# prod 環境
cd ../prod
terraform init
terraform plan
terraform apply
```

#### 初回実行時の所要時間の目安

| リソース | 所要時間目安 |
|---|---|
| PostgreSQL フレキシブルサーバー | 10〜15 分 |
| App Service | 2〜5 分 |
| Key Vault | 1〜2 分 |
| 全体 | 15〜25 分 |

---

### 5.2 CI/CD 経由でのデプロイ

初回デプロイ後、コードの変更は GitHub Actions 経由でデプロイします。

#### フロー

1. フィーチャーブランチで変更をコミット・プッシュ
2. `main` ブランチへの Pull Request を作成
3. `terraform-plan.yml` が自動実行され、PR にプラン結果がコメントされる
4. レビュアーがプラン内容を確認し、PR をマージ
5. `terraform-apply.yml` が自動実行され、変更が適用される

---

## 6. Terraform 適用後の手動設定

`terraform apply` 完了後、以下の設定を Azure Portal で手動で行います。

### 6.1 Entra ID API アクセス許可への管理者同意

Terraform で作成された Entra ID アプリ登録に対して、Microsoft Graph スコープへの管理者同意を付与します。

1. [Azure Portal](https://portal.azure.com) にグローバル管理者またはアプリケーション管理者でサインイン
2. **Microsoft Entra ID** > **アプリの登録** を開く
3. `app-<env>-<project_name>` を選択（例: `app-dev-mywebapp`）
4. 左メニューから **API のアクセス許可** を選択
5. **`<テナント名>` に管理者の同意を与えます** ボタンをクリック
6. 確認ダイアログで **はい** をクリック
7. `openid`、`profile`、`email` の **状態** が **許可済み** になっていることを確認

> **注意:** 管理者同意はテナント内のユーザーが同意プロンプトなしにアプリを使用できるようにするために必要です。環境 (dev / staging / prod) ごとに繰り返します。

---

### 6.2 App Service 認証の設定

App Service の Easy Auth (組み込み認証) を設定します。

1. **Azure Portal** > **App Service** > `app-<env>-<suffix>` を開く
2. 左メニューから **認証** を選択
3. **ID プロバイダーを追加する** をクリック
4. 以下を設定:

   | 項目 | 値 |
   |---|---|
   | ID プロバイダー | Microsoft |
   | アプリの登録の種類 | 既存アプリの登録の詳細を指定する |
   | アプリケーション (クライアント) ID | Terraform 出力の `entra_client_id` |
   | クライアントシークレット | Terraform 出力の `entra_client_secret` |
   | 発行者 URL | `https://login.microsoftonline.com/<TENANT_ID>/v2.0` |
   | 認証されていない要求 | HTTP 302 リダイレクト |

5. **追加** をクリック

#### Terraform の出力値を確認する方法

```bash
cd environments/dev
terraform output
# または特定の値のみ
terraform output -raw entra_client_id
terraform output -raw entra_client_secret
```

> **注意:** `entra_client_secret` は機密情報のため `sensitive = true` が設定されています。`terraform output -raw entra_client_secret` で表示できます。

---

## 7. 動作確認

### App Service の疎通確認

```bash
# App Service のデフォルト URL にアクセス
# ブラウザで https://app-<env>-<suffix>.azurewebsites.net を開く
# 認証が設定されている場合、Microsoft サインインページにリダイレクトされることを確認
```

### PostgreSQL への接続確認

PostgreSQL はパブリックアクセスが無効のため、App Service 経由での接続のみ可能です。App Service の **コンソール (SSH)** または **高度なツール (Kudu)** から接続を確認します。

```bash
# App Service の SSH コンソールから
psql "postgresql://pgadmin@psql-<env>.postgres.database.azure.com/appdb?sslmode=require"
```

### Key Vault のシークレット確認

```bash
# App Service の Managed Identity から Key Vault へアクセスできることを確認
# App Service の環境変数 KEY_VAULT_URI が正しく設定されていることを確認
az keyvault secret list --vault-name "kv-<env>-<suffix>"
```

### Log Analytics のログ確認

1. **Azure Portal** > **Log Analytics ワークスペース** > `log-<env>` を開く
2. **ログ** を選択し、以下のクエリを実行して診断ログが届いていることを確認:

```kusto
// App Service のログ確認
AppServiceHTTPLogs
| limit 10

// Key Vault の監査ログ確認
AzureDiagnostics
| where ResourceType == "VAULTS"
| limit 10
```

---

## 8. トラブルシューティング

### `terraform init` でバックエンドエラーが発生する

**症状:** `Error: Failed to get existing workspaces`

**原因と対処:**
- `storage_account_name` が正しく設定されていない → [4.1](#41-backend-の-storage_account_name-を埋める) を確認
- サービスプリンシパルに `Storage Blob Data Contributor` ロールが付与されていない → [2.3](#23-github-actions-用サービスプリンシパルoidc-の設定) の権限付与を確認
- ストレージアカウントが存在しない → [2.2](#22-tfstate-管理用ストレージアカウントの作成) の手順を再確認

### `terraform plan` で認証エラーが発生する

**症状:** `Error: building AzureRM Client: obtain subscription(XXXXXXXX): ...`

**原因と対処:**
- Azure CLI でログインしていない → `az login` を実行
- サブスクリプションが設定されていない → `az account set --subscription "<ID>"` を実行

### GitHub Actions で OIDC 認証エラーが発生する

**症状:** `Error: AADSTS70021: No matching federated identity record found`

**原因と対処:**
- Federated Credentials の `subject` が実際の GitHub Actions のコンテキストと一致していない
- Environment を使用している場合、Environment 用のフェデレーション認証が設定されていない → [2.3](#23-github-actions-用サービスプリンシパルoidc-の設定) の Environment 用フェデレーション認証設定を確認

### PostgreSQL が作成できない

**症状:** `Error: creating PostgreSQL Flexible Server: ... The zone is not available`

**原因と対処:**
- 指定した可用性ゾーンがリージョンでサポートされていない
- `availability_zone` の値を変更するか、`null` に設定

### Key Vault を削除後に再作成できない

**症状:** `Error: A resource with the ID ... already exists`

**原因と対処:**
- Key Vault はソフト削除が有効なため、削除後も一定期間は回復可能状態で残る
- Azure Portal で **削除済み Key Vault** から完全削除 (Purge) するか、以下のコマンドを実行:

```bash
az keyvault purge --name "kv-<env>-<suffix>" --location "japaneast"
```

> **注意:** prod 環境では `purge_protection_enabled = true` のため、保持期間 (7日) が経過するまで Purge できません。

### App Service から Key Vault にアクセスできない

**症状:** アプリケーションで `403 Forbidden` エラーが発生する

**原因と対処:**
- Managed Identity が有効になっていない
- `Key Vault Secrets User` ロールの割り当てが完了していない（伝播に最大 5 分かかる場合がある）
- Key Vault のネットワーク ACL で App Service が許可されていない

```bash
# Managed Identity のオブジェクト ID を確認
az webapp identity show \
  --name "app-<env>-<suffix>" \
  --resource-group "rg-<project>-<env>" \
  --query principalId

# RBAC ロールの割り当てを確認
az role assignment list \
  --assignee "<principalId>" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-<project>-<env>/providers/Microsoft.KeyVault/vaults/kv-<env>-<suffix>"
```
