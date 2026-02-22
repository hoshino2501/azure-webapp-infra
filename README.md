# azure-webapp-infra

Azure 上に構築する Web アプリケーションインフラの Terraform 定義コードです。

## アーキテクチャ概要

```mermaid
graph TB
    Internet["インターネット"]
    EntraID["Microsoft Entra External ID<br/>(外部ユーザー認証・認可)"]

    subgraph VNet["Virtual Network"]
        AppService["Azure App Service<br/>(VNet 統合 + Managed Identity)"]
        PostgreSQL["Azure Database for PostgreSQL<br/>フレキシブルサーバー<br/>(VNet インジェクション)"]
        KeyVault["Azure Key Vault<br/>(機密情報の保管)"]
    end

    LogAnalytics["Log Analytics Workspace<br/>(ログ集約・監視)"]

    Internet -->|HTTPS| AppService
    Internet -->|認証| EntraID
    AppService -->|認可確認| EntraID
    AppService -->|DB 接続| PostgreSQL
    AppService -->|Managed Identity 経由で参照| KeyVault
    AppService -->|診断ログ| LogAnalytics
    PostgreSQL -->|診断ログ| LogAnalytics
```

| コンポーネント | 用途 |
|---|---|
| Virtual Network | ネットワーク境界の確立。PostgreSQL・Key Vault をインターネット非公開にする |
| Azure App Service | Web アプリケーションのホスティング（VNet 統合 + Managed Identity を有効化） |
| Azure Database for PostgreSQL フレキシブルサーバー | アプリケーションのバックエンド DB（VNet インジェクションでプライベートアクセス） |
| Azure Key Vault | DB パスワード等の機密情報を一元管理。App Service は Managed Identity 経由で参照 |
| Log Analytics Workspace | App Service・PostgreSQL の診断ログ・メトリクスの集約と監視 |
| Microsoft Entra External ID | 外部ユーザー向けの認証・認可 |

## ディレクトリ構成

```
.
├── environments/               # 環境ごとの設定
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
├── modules/                    # 再利用可能なモジュール
│   ├── networking/             # Virtual Network・サブネット
│   ├── app_service/            # Azure App Service
│   ├── postgresql/             # Azure Database for PostgreSQL
│   ├── key_vault/              # Azure Key Vault
│   ├── log_analytics/          # Log Analytics Workspace
│   └── entra_external_id/      # Microsoft Entra External ID
└── .github/
    └── workflows/
        ├── terraform-plan.yml  # PR 時に plan を実行
        └── terraform-apply.yml # main マージ時に apply を実行
```

## 前提条件

### 必要なツール

| ツール | 推奨バージョン |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | 1.9 以上 |
| [Azure CLI](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli) | 2.60 以上 |

### 必要な Azure 権限

- 対象サブスクリプションの `Contributor` ロール
- Microsoft Entra の `Application Administrator` ロール

## 初期セットアップ

### 1. tfstate 用ストレージの作成

tfstate は Azure Blob Storage で管理します。初回のみ以下を実行してください。

```bash
# 変数定義
RESOURCE_GROUP="rg-tfstate"
STORAGE_ACCOUNT="stterraformstate$(openssl rand -hex 4)"
CONTAINER="tfstate"
LOCATION="japaneast"

# リソース作成
az group create --name $RESOURCE_GROUP --location $LOCATION
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --min-tls-version TLS1_2
az storage container create \
  --name $CONTAINER \
  --account-name $STORAGE_ACCOUNT

echo "Storage Account Name: $STORAGE_ACCOUNT"
```

作成後、`environments/<env>/main.tf` の backend 設定にストレージアカウント名を記載してください。

### 2. Azure CLI でログイン

```bash
az login
az account set --subscription "<サブスクリプション ID>"
```

### 3. Terraform 設定ファイルの編集

#### backend の設定

`environments/<env>/main.tf` の backend ブロックに、手順 1 で作成したストレージアカウント名を記載してください。
対象ファイル: `environments/dev/main.tf`, `environments/staging/main.tf`, `environments/prod/main.tf`

```hcl
backend "azurerm" {
  resource_group_name  = "rg-tfstate"
  storage_account_name = "<手順1で作成したストレージアカウント名>"  # ← ここを記入
  container_name       = "tfstate"
  key                  = "dev/terraform.tfstate"
}
```

#### terraform.tfvars の編集

`environments/<env>/terraform.tfvars` を開き、以下の値を実際の値に変更してください。

| 変数 | 説明 |
|---|---|
| `entra_tenant_id` | Azure テナント ID（`az account show --query tenantId -o tsv` で確認できます） |
| `suffix` | Key Vault・App Service などグローバル一意が必要なリソース名のサフィックス。他のサブスクリプションと重複しない文字列に変更してください |

#### 機密情報の設定

DB パスワード等の機密情報は `terraform.tfvars` に記載せず、環境変数で渡してください。

```bash
export TF_VAR_db_password="your-secret-password"
```

### 4. Entra External ID の追加設定（terraform apply 後）

`terraform apply` でアプリ登録は自動作成されますが、以下の手順は Azure Portal で手動実行が必要です。

1. **API 権限への管理者同意**
   Azure Portal → Microsoft Entra ID → アプリの登録 → `app-<env>-<project_name>` を開く
   → 「API のアクセス許可」 → 「<テナント名> に管理者の同意を与えます」をクリック

2. **App Service 認証の有効化**
   Azure Portal → App Service → 「認証」 → 「ID プロバイダーを追加」
   → Microsoft を選択し、`terraform output entra_client_id` で取得したクライアント ID を設定

3. **クライアントシークレットの有効期限管理**
   クライアントシークレットの有効期限は dev/staging では `2026-12-31`、prod では `2027-12-31` に設定されています。
   期限切れ前に `terraform apply` でシークレットを更新してください（`client_secret_expiry` 変数で管理）。

## 使い方

### Terraform の実行

```bash
# 対象環境のディレクトリへ移動（例: dev）
cd environments/dev

# 初期化
terraform init

# 変更内容の確認
terraform plan

# 適用
terraform apply
```

## 環境ごとの設定差異

各環境の主なリソース設定は以下のとおりです。

| 項目 | dev | staging | prod |
|---|---|---|---|
| App Service SKU | B1 | P1v3 | P2v3 |
| App Service Always On | 無効 | 有効 | 有効 |
| PostgreSQL SKU | B_Standard_B1ms | GP_Standard_D2s_v3 | GP_Standard_D4s_v3 |
| PostgreSQL ストレージ | 32 GB | 64 GB | 128 GB |
| DBバックアップ保持期間 | 7 日 | 14 日 | 35 日 |
| DB geo冗長バックアップ | 無効 | 無効 | 有効 |
| Log Analytics ログ保持期間 | 30 日 | 60 日 | 90 日 |
| Key Vault Purge Protection | 無効 | 無効 | **有効** |
| VNet アドレス空間 | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |

> **prod の Key Vault Purge Protection について**: `purge_protection_enabled = true` が設定されています。これを有効にすると Key Vault を削除しても保持期間内は完全消去できなくなります。リソースの再作成が必要な場合は注意してください。

## GitHub Actions による CI/CD

| ワークフロー | トリガー | 処理 |
|---|---|---|
| `terraform-plan.yml` | Pull Request 作成・更新時 | `terraform plan` を実行し結果を PR にコメント |
| `terraform-apply.yml` | `main` ブランチへのマージ時 | `terraform apply` を自動実行 |

### GitHub Actions に必要なシークレット

リポジトリの Settings > Secrets and variables > Actions に以下を登録してください。

| シークレット名 | 説明 |
|---|---|
| `AZURE_CLIENT_ID` | サービスプリンシパルのクライアント ID |
| `AZURE_TENANT_ID` | Azure テナント ID |
| `AZURE_SUBSCRIPTION_ID` | Azure サブスクリプション ID |
| `TF_VAR_DB_PASSWORD` | PostgreSQL 管理者パスワード（`terraform apply` 時に `TF_VAR_db_password` として渡されます） |

> GitHub Actions からの認証には、パスワードレスな **OpenID Connect (OIDC)** 方式を推奨します。

## ドキュメント

| ドキュメント | 説明 |
|---|---|
| [インフラ設計書](docs/infrastructure-design.md) | アーキテクチャの設計方針・各コンポーネントの詳細設計 |
| [インフラ構築手順書](docs/setup-guide.md) | 初回セットアップから `terraform apply` までの手順 |
| [プラン選定ガイド](docs/plan-selection-guide.md) | App Service・PostgreSQL のプラン選定基準と環境ごとの推奨設定 |
| [運用手順書](docs/operations-guide.md) | デプロイ・監視・障害対応などの日常運用タスク |

## セキュリティに関する注意事項

- **tfstate には機密情報が含まれます。** Blob Storage のアクセス制御を適切に設定し、パブリックアクセスは無効にしてください。
- `terraform.tfvars` に機密情報を記載しないでください。`.gitignore` に追加することを推奨します。
- DB のパスワードなどの機密値は [Azure Key Vault](https://learn.microsoft.com/ja-jp/azure/key-vault/) での管理を推奨します。
- サービスプリンシパルには最小権限の原則に従い、必要最低限のロールのみ付与してください。
