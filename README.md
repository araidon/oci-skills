# oci-skills

OCI（Oracle Cloud Infrastructure）向けの AI コーディングアシスタント用 **Skills コレクション**です。

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) と [Codex（OpenAI）](https://openai.com/index/introducing-codex/) の両方で利用できます。

---

## 収録スキル

### oci-drawio — OCI 構成図ジェネレーター

自然言語の指示から **draw.io 形式（.drawio）の OCI アーキテクチャ構成図**を生成するスキルです。

- 「3層Webアプリのアーキテクチャ図を描いて」のような指示で構成図を生成
- 既存の `.drawio` ファイルを読み込んで編集・追記
- **AWS / Azure の構成図を OCI へ変換**（サービス対応表つき）
- Oracle 公式の OCI アイコンを使用（234コンポーネント同梱）
- Region → VCN → Subnet → Service の OCI 標準レイアウトに自動配置

#### 仕組み

構成図の XML を AI に直接書かせると、アイコン1個あたり数千文字の base64 を出力する
ことになり、10個ほどで出力上限に達して壊れたファイルができます。このスキルでは、
AI は 1〜2KB のスペックだけを書き、`.drawio` の組み立てはスクリプトが行います。

```
AI が書くスペック（約1KB）        →  build_drawio.py  →  正しい .drawio
{"region": "...", "vcn": {...}}                          （検証つき）
```

生成後は `validate_drawio.py` が、XML の妥当性・参照切れ・アイコンデータの破損・
要素のはみ出し・重なりを機械的にチェックします。

#### 対応コンポーネント

全234コンポーネント／13カテゴリ。完全な一覧は
[`skills/oci-drawio/reference/component-list.md`](skills/oci-drawio/reference/component-list.md)。

| カテゴリ | 件数 | 例 |
|---|---|---|
| Networking | 22 | VCN, Internet Gateway, NAT Gateway, Service Gateway, DRG, Load Balancer, Flexible Load Balancer, DNS, CDN, CPE |
| Compute | 9 | VM Instance, Bare Metal, Flex VM, Autoscaling, Instance Pools, Functions |
| Database | 48 | Autonomous Database, MySQL HeatWave, MySQL DB System, DB System, Exadata, Data Guard, GoldenGate |
| Storage | 18 | Object Storage, Block Volume, File Storage, Buckets |
| Identity & Security | 27 | WAF, Network Firewall, Vault, Bastion, IAM, NSG, Cloud Guard, Compartments |
| Developer Services | 21 | OKE, Container Instances, OCIR, API Gateway, DevOps, Resource Manager |
| Observability & Management | 14 | Logging, Monitoring, Alarms, Auditing, Events, Queuing |
| Analytics & AI | 20 | Data Science, Data Flow, Generative AI, Streaming, Vision, Speech |
| その他 | 55 | Applications / Governance / Hybrid / Migration / General |

`VPC` `IGW` `ADB` `OSS` `KMS` `Kubernetes` などの略称・別名でも指定できます。

#### サンプル構成図

`skills/oci-drawio/examples/` にあります。生成元のスペックは `examples/specs/`。

- **basic-web-3tier.drawio** — LB + Web/App × 3 + Autonomous Database
- **ha-architecture.drawio** — WAF、内部LB、Web/App 冗長化、Data Guard、オンプレ接続

---

## インストール

### Claude Code（プラグイン・推奨）

clone 不要で、Claude Code から直接インストールできます。

```
/plugin marketplace add araidon/oci-skills
/plugin install oci-drawio@oci-skills
```

更新は `/plugin marketplace update` です。

### Claude Code / Codex（install.sh）

```bash
git clone https://github.com/araidon/oci-skills.git
cd oci-skills
./install.sh oci-drawio
```

| インストール先 | `--tool` | パス |
|---|---|---|
| Claude Code（グローバル） | `claude`（既定） | `~/.claude/skills/<name>/` |
| Claude Code（プロジェクト） | `claude-local` | `.claude/skills/<name>/` |
| Codex（グローバル） | `codex` | `~/.codex/skills/<name>/` |
| Codex（プロジェクト） | `codex-local` | `.codex/skills/<name>/` |
| Codex（リポジトリスキャン） | `codex-repo` | `.agents/skills/<name>/` |

```bash
./install.sh --list                       # 一覧
./install.sh --all                        # 全部入れる
./install.sh oci-drawio --tool codex      # Codex に入れる
./install.sh --uninstall oci-drawio       # 消す
./install.sh oci-drawio -y                # 上書き確認を省略
```

既存のインストールを上書きする場合は確認を求めます（`-y` で省略）。

### 前提条件

- Git / Bash
- Python 3.8 以上（構成図の生成・検証に使用）
- PyYAML（任意。スペックを YAML で書きたい場合のみ）

**アイコンは同梱済みなので、セットアップ不要でそのまま使えます。**

---

## 使い方

```
> OCI上に3層Webアプリの構成図を描いてください。
> LBの後ろにWebサーバー2台、プライベートサブネットにAppサーバーと
> Autonomous Databaseを配置してください。
```

### 既存ファイルの編集

```
> web-architecture.drawio にNATゲートウェイを追加してください。
> 既存の構成図にWAFとBastionを追加して、高可用性構成にしてください。
```

### AWS / Azure からの変換

```
> このAWSの構成図をOCIに置き換えた図を作ってください。（画像を添付）
```

サービス対応表と、1:1 対応しない箇所の注意点もあわせて出力されます。

生成された `.drawio` は [draw.io](https://app.diagrams.net/)（デスクトップ版・Web版）で
そのまま開けます。

### draw.io の GUI で手描きする場合

`skills/oci-drawio/icons/oci-shapes.xml` をシェイプライブラリとして読み込めます。

```
draw.io → File → Open Library → oci-shapes.xml
```

---

## アイコンの更新

Oracle がアイコンセットを更新したときだけ実行します（通常は不要）。

```bash
cd ~/.claude/skills/oci-drawio
bash setup.sh                          # Oracle からダウンロード
bash setup.sh --from-zip icons.zip     # 手元の zip から（ネットワーク不要）
```

必要なツール: `curl` `unzip` `base64` `python3`

生成は一時領域で行い、検証を通ったときだけ差し替えるため、失敗しても既存のデータは
壊れません。

---

## 注意事項

- OCI アイコンの著作権は Oracle Corporation に帰属します。利用にあたっては Oracle の
  ブランドガイドラインに従ってください。
- draw.io の MCP サーバーは使用せず、`.drawio`（XML）を直接生成する方式です。
  追加のサーバー設定は不要です。

---

## ライセンス

コードは MIT License です（[LICENSE](LICENSE)）。
OCI アイコンは Oracle Corporation に帰属し、MIT License の対象外です。
