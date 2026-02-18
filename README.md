# oci-skills

OCI（Oracle Cloud Infrastructure）向けの AI コーディングアシスタント用 **Skills コレクション**です。

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) と [Codex（OpenAI）](https://openai.com/index/introducing-codex/) の両方で利用できます。スキルをインストールすると、AI アシスタントが OCI 関連の作業を自動化・効率化してくれます。

---

## 収録スキル

### oci-drawio — OCI 構成図ジェネレーター

自然言語の指示から **draw.io 形式（.drawio）の OCI アーキテクチャ構成図**を自動生成するスキルです。

- 「3層Webアプリのアーキテクチャ図を描いて」のような指示で構成図を生成
- 既存の `.drawio` ファイルを読み込んで編集・追記も可能
- Oracle 公式の OCI アイコンを使用（ブランドガイドラインに準拠）
- Region → VCN → Subnet → Service の OCI 標準レイアウトに自動配置

#### 対応コンポーネント

| カテゴリ | コンポーネント |
|---------|-------------|
| **Networking** | VCN, Subnet, Internet Gateway, NAT Gateway, Service Gateway, DRG, Load Balancer, Network Load Balancer, DNS, FastConnect, VPN |
| **Compute** | VM Instance, Bare Metal, Autoscaling, Instance Pools, Functions |
| **Database** | Autonomous Database, MySQL HeatWave, DB System, Exadata |
| **Storage** | Object Storage, Block Volume, File Storage, Buckets |
| **Security** | WAF, Network Firewall, Vault, Bastion, IAM |
| **Container** | OKE, Container Instances, OCIR |
| **Monitoring** | Streaming, Notifications, Logging, Monitoring |

#### サンプル構成図

`skills/oci-drawio/examples/` にサンプルが含まれています。

- **basic-web-3tier.drawio** — 基本的な 3 層 Web アーキテクチャ（LB + Web + App + ADB）
- **ha-architecture.drawio** — 高可用性構成（WAF、冗長 Web/App サーバー、Data Guard）

---

## インストール

### 前提条件

- Git
- Bash

### 手順

```bash
# 1. リポジトリをクローン
git clone https://github.com/araidon/oci-skills.git
cd oci-skills

# 2. スキルをインストール
./install.sh oci-drawio                    # Claude Code の場合
./install.sh oci-drawio --tool codex       # Codex の場合
```

### install.sh のオプション

```bash
# Claude Code にインストール（デフォルト）
./install.sh oci-drawio

# Codex にインストール（グローバル）
./install.sh oci-drawio --tool codex

# Codex にインストール（プロジェクトローカル）
./install.sh oci-drawio --tool codex-local

# Codex にインストール（リポジトリスキャン用）
./install.sh oci-drawio --tool codex-repo

# 利用可能なスキル一覧
./install.sh --list

# 全スキルを一括インストール
./install.sh --all
```

| インストール先 | パス | 用途 |
|--------------|------|------|
| Claude Code | `~/.claude/skills/<name>/` | Claude Code で利用 |
| Codex（グローバル） | `~/.codex/skills/<name>/` | 全プロジェクトで利用 |
| Codex（プロジェクト） | `.codex/skills/<name>/` | 特定プロジェクトで利用 |
| Codex（リポジトリ） | `.agents/skills/<name>/` | リポジトリスキャン |

---

## セットアップ（oci-drawio）

インストール後、初回のみセットアップスクリプトを実行して OCI アイコンを取得する必要があります。

### 必要なツール

- `curl`
- `unzip`
- `base64`
- `python3`

### 実行

```bash
# Claude Code の場合
cd ~/.claude/skills/oci-drawio && bash setup.sh

# Codex の場合
cd ~/.codex/skills/oci-drawio && bash setup.sh
```

セットアップが完了すると以下が生成されます：

- `icons/oci-shapes.xml` — draw.io 用カスタムアイコンライブラリ
- `components/oci_components.json` — コンポーネント辞書（スタイル情報付き）

---

## 使い方

インストールとセットアップが完了すれば、AI アシスタントに指示するだけで構成図を生成できます。

### 構成図の生成（Claude Code / Codex 共通）

インストール済みの AI アシスタントに、以下のように指示するだけで構成図が生成されます。

```
> OCI上に3層Webアプリの構成図を描いてください。
> LBの後ろにWebサーバー2台、プライベートサブネットにAppサーバーとAutonomous Databaseを配置してください。
```

### 既存ファイルの編集

```
> web-architecture.drawio にNATゲートウェイを追加してください。
> 既存の構成図にWAFとBastionを追加して、高可用性構成にしてください。
```

生成された `.drawio` ファイルは [draw.io](https://app.diagrams.net/)（デスクトップ版・Web版）でそのまま開けます。

---

## 注意事項

- OCI アイコンは Oracle 公式サイトからダウンロードしています。アイコンの利用にあたっては Oracle のブランドガイドラインに従ってください。
- `setup.sh` の実行にはインターネット接続が必要です。
- draw.io の MCP サーバーは使用せず、XML テキストを直接生成する方式を採用しています。そのため追加のサーバー設定は不要です。

---

## ライセンス

このリポジトリのコードは MIT License で公開されています。

OCI アイコンの著作権は Oracle Corporation に帰属します。
