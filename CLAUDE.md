# oci-skills プロジェクト

## プロジェクト概要

Claude Code / Codex（OpenAI）の両方で使える **Skills コレクション**のリポジトリ。
OCI（Oracle Cloud Infrastructure）関連の作業を自動化・効率化するSkillを収録する。

配布方法はGitHub公開。ユーザーはcloneしてローカルのskillsディレクトリに配置して使う。

---

## リポジトリ構成

```
oci-skills/
├── CLAUDE.md                    # このファイル（Claude Codeへの指示書）
├── README.md                    # ユーザー向け説明・Skill一覧
├── CONTRIBUTING.md              # Skill追加ガイドライン
├── install.sh                   # 任意のSkillをインストールするCLI
│
└── skills/
    └── oci-drawio/              # 最初のSkill：OCI構成図生成
        ├── SKILL.md             # Claude/Codexが読む指示書（最重要）
        ├── setup.sh             # 初回セットアップ（アイコン取得）
        ├── components/
        │   └── oci_components.json   # コンポーネント→style辞書
        ├── icons/               # setup.sh実行後に生成されるアイコン
        │   └── oci-shapes.xml   # draw.io用カスタムライブラリ
        ├── templates/
        │   └── base_diagram.drawio   # 枠組みテンプレート
        └── examples/
            ├── basic-web-3tier.drawio
            └── ha-architecture.drawio
```

---

## 最初のタスク：`skills/oci-drawio/` の実装

### タスク1: `setup.sh` の作成

以下の処理を行うシェルスクリプト：

1. Oracle公式からOCIアイコンセット（SVG）をダウンロード
   - 公式URL: https://docs.oracle.com/en-us/iaas/Content/General/Reference/graphicsfordiagrams.htm
   - SVG形式のzipをダウンロード・展開
2. SVGファイルをdraw.io用のstyle文字列に変換
3. `icons/oci-shapes.xml`（draw.ioカスタムライブラリ）を生成
4. `components/oci_components.json`（コンポーネント辞書）を生成

### タスク2: `components/oci_components.json` の作成

Claude/Codexが構成図生成時に参照するコンポーネント辞書。
以下のカテゴリのコンポーネントを最低限カバーする：

- **Networking**: VCN, Subnet (Public/Private), Internet Gateway, NAT Gateway, Service Gateway, Load Balancer, DRG
- **Compute**: VM Instance, Bare Metal, Autoscaling
- **Database**: Autonomous Database, MySQL HeatWave, DB System
- **Storage**: Object Storage, Block Volume, File Storage
- **Security**: WAF, Vault, Bastion
- **Container**: OKE, Container Instances, OCIR

フォーマット例：
```json
{
  "VCN": {
    "style": "shape=image;verticalLabelPosition=bottom;labelPosition=center;verticalAlign=top;image=img/lib/oci/networking/virtual_cloud_network.svg;",
    "width": 60,
    "height": 60,
    "category": "networking",
    "description": "Virtual Cloud Network",
    "color_hex": "#312D2A"
  }
}
```

### タスク3: `SKILL.md` の作成

Claude CodeとCodexが読む最重要ファイル。以下を記述する：

**Codex向けフロントマター（ファイル先頭に必須）：**
```markdown
---
name: oci-drawio
description: Generate and edit OCI architecture diagrams in draw.io (.drawio) format. Use this skill when asked to create, update, or modify OCI architecture diagrams.
---
```
Claude Codeはフロントマター不要だが、Codexはnameとdescriptionがないとスキルを認識しない。両対応のため必ず記述する。

**含めるべき内容：**
- このSkillの目的と使い方
- 前提条件（setup.sh実行済みであること）
- draw.io XMLの生成ルール
- OCIレイアウト規則（Region → VCN → AD/Subnet → Serviceの階層）
- グリッドシステム（座標計算の規則）
- コンポーネント辞書（oci_components.json）の参照方法
- 既存.drawioファイルの編集方法（XMLを読み込んで追記・修正）
- 出力ファイルの保存方法

### タスク4: `install.sh` の作成（ルートに配置）

```bash
# 使い方
./install.sh oci-drawio                      # Claude Code（デフォルト）
./install.sh oci-drawio --tool codex         # Codex グローバル（~/.codex/skills/）
./install.sh oci-drawio --tool codex-local   # Codex プロジェクト（.codex/skills/）
./install.sh --list                          # 利用可能なSkill一覧
./install.sh --all                           # 全部インストール
```

インストール先：
- Claude Code: `~/.claude/skills/<skill-name>/`
- Codex（ユーザーグローバル）: `~/.codex/skills/<skill-name>/`
- Codex（プロジェクトローカル）: `.codex/skills/<skill-name>/` （リポジトリ内）
- Codex（リポジトリスキャン）: `.agents/skills/<skill-name>/` （git rootから上位に向けてスキャン）

---

## 技術的決定事項（変更しないこと）

| 項目 | 決定内容 | 理由 |
|------|---------|------|
| draw.io MCPサーバー | **使わない** | 配布のしやすさを優先。XMLテキスト直接生成で十分 |
| アイコン形式 | SVG（Oracle公式から取得） | 公式ブランドガイドラインに準拠 |
| 生成形式 | .drawioファイル（XML） | draw.io desktop/webで直接開ける |
| 対応ツール | Claude Code + Codex（OpenAI）両対応 | SKILL.mdはツール非依存の記述にする |
| 編集ユースケース | XMLファイルを直接読み書き | MCPなしで実現可能 |

---

## draw.io XML の基本構造（参考）

```xml
<mxfile>
  <diagram name="OCI Architecture">
    <mxGraphModel>
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        <!-- Region（最外枠） -->
        <mxCell id="2" value="Japan East (Tokyo)" style="points=...;shape=mxgraph.oracle2.region;" vertex="1" parent="1">
          <mxGeometry x="0" y="0" width="800" height="600" as="geometry"/>
        </mxCell>
        <!-- VCN -->
        <mxCell id="3" value="VCN" style="..." vertex="1" parent="2">
          <mxGeometry x="20" y="40" width="760" height="520" as="geometry"/>
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

## OCIレイアウト規則

階層構造（ADの表記は不要）：
```
┌─ Region ──────────────────────────────────────────────────────┐
│  ┌─ VCN ──────────────────────────────────┐                   │
│  │                                         │                   │
│ [IGW]  ┌─ Public Subnet ─────────────┐   [SGW]  [Object Storage] │
│ [NAT]  │  [LB]  [Bastion]  ...       │    │     [Vault]        │
│ [DRG]  └─────────────────────────────┘    │     [OCIR]         │
│  │     ┌─ Private Subnet ────────────┐    │     [Streaming]    │
│  │     │  [App]  [DB]  ...           │    │     ...            │
│  │     └─────────────────────────────┘    │                   │
│  └─────────────────────────────────────────┘                   │
└───────────────────────────────────────────────────────────────┘
```

### Gatewayの配置ルール

| Gateway | 配置場所 |
|---------|---------|
| Internet Gateway (IGW) | VCNの**左側の枠線上** |
| NAT Gateway | VCNの**左側の枠線上**（IGWの下） |
| DRG | VCNの**左側の枠線上**（NATの下） |
| Service Gateway (SGW) | VCNの**右側の枠線上** |

アイコンはVCNの枠線をまたぐように配置する（枠線の中心にアイコン中心を合わせる）。

### リージョナルサービスの配置ルール

VCNに属さないマネージドサービスは **Regionの枠内・VCNの右側** に縦並びで配置する。SGWの右隣から始める。

対象サービスの例：
- Object Storage
- Vault / Key Management
- Autonomous Database（プライベートエンドポイントなしの場合）
- OCI Registry (OCIR)
- Streaming
- Notifications / Queue
- IAM / Identity
- Logging / Monitoring / Audit

### 接続線のルール

- 線のみ（矢印の先端・終端なし）
- IGW/NAT/DRG ↔ Subnet間：VCNの左枠線を経由して水平線で接続
- SGW ↔ リージョナルサービス間：VCNの右枠線上のSGWから水平線で接続
- 線のスタイル: `endArrow=none;startArrow=none;`

### コンテナの色設定（Oracle公式準拠）

| コンテナ | 枠線色 | 背景色 | 備考 |
|---------|--------|--------|------|
| Region | `#D04A02`（薄いオレンジ赤） | `#FFFFFF`（白） または 透明 | 細い実線 |
| VCN | `#878787`（グレー） | `#F5F5F5`（薄いグレー） | 細い実線 |
| Public Subnet | `#878787`（グレー） | `#FFFFFF`（白） | 細い実線・ラベルで区別 |
| Private Subnet | `#878787`（グレー） | `#EFEFEF`（少し暗めのグレー） | 細い実線・ラベルで区別 |

**基本方針：**
- 色による区別は最小限にする（公式構成図はほぼグレー系で統一）
- Public/Privateの区別はラベルと配置で表現するのが主流
- 派手な青・橙などの塗りつぶしは使わない
- アイコン自体の色（Oracleブランドカラー）が主役

### 座標規則
- コンテナ間の余白: 20px
- アイコンサイズ: 60x60px
- アイコン間隔: 100px
- ラベル: アイコン下部に配置

---

## 将来追加予定のSkill（参考）

- `oci-terraform/` : 構成情報からTerraformコードを生成
- `oci-cost-estimator/` : 構成からOCIコスト見積もりを生成
- `oci-competitive/` : AWS↔OCI比較・移行支援
- `qiita-writer/` : OCI技術記事のテンプレート生成

---

## 作業開始の手順

```bash
# 1. まずsetup.shを作成・テスト
# 2. components/oci_components.jsonを作成（主要30コンポーネント）
# 3. SKILL.mdを作成
# 4. examples/にサンプル構成図を生成して動作確認
# 5. install.shを作成
# 6. README.mdを整備
```

不明点があれば @araidon に確認すること。
