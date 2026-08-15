---
name: oci-drawio
description: OCI（Oracle Cloud Infrastructure）のアーキテクチャ構成図を draw.io 形式（.drawio）で生成・編集する。AWS/Azure の構成図を OCI へ変換することもできる。Generate, edit, and convert OCI architecture diagrams in draw.io (.drawio) format using official Oracle icons.
when_to_use: 「OCIの構成図を書いて」「アーキテクチャ図を作って」「drawioで図を作って」「この構成をOCIに置き換えて」「AWSの構成図をOCIに変換して」など、OCI の構成図・アーキテクチャ図の作成／編集／他クラウドからの変換を求められたとき。既存の .drawio ファイルへの追記・修正も含む。
license: MIT
---

# OCI draw.io 構成図スキル

Oracle 公式アイコンを使って OCI アーキテクチャ図（`.drawio`）を生成・編集する。

## 重要な前提

アイコンは1つあたり中央値 4,177 文字の base64 を含む（最大 286,555 文字）。
**XML を手書きすると10アイコン程度で出力トークン上限に達し、途中で切れた壊れた
ファイルができる。** そのため新規作成は必ず生成スクリプトを使う。

---

## 手順: 新規作成

### 1. コンポーネント名を確認する

`components/index.json`（8KB）を読むか、名前解決を直接試す。

```bash
python3 scripts/oci_components.py "ロードバランサー相当" "ADB" "kubernetes"
```

別名・略称（`VPC` `IGW` `ADB` `OSS` `KMS` `Kubernetes` など）や部分一致でも解決できる。
一覧は `reference/component-list.md`（234件・カテゴリ別）。

### 2. スペックを書く

1〜2KB の JSON か YAML。座標も base64 も書かない。

```json
{
  "title": "OCI 3-Tier Web Architecture",
  "region": "Japan East (Tokyo)",
  "vcn": {
    "label": "VCN (10.0.0.0/16)",
    "gateways": { "left": ["Internet Gateway", "NAT Gateway"], "right": ["Service Gateway"] },
    "subnets": [
      { "label": "Edge Subnet (10.0.1.0/24)", "nodes": [{ "component": "Load Balancer", "id": "lb" }] },
      { "label": "App Subnet (10.0.2.0/24)", "nodes": ["VM Instance x3"] },
      { "label": "Data Subnet (10.0.3.0/24)", "nodes": [{ "component": "Autonomous Database", "id": "db" }] }
    ]
  },
  "regional_services": ["Object Storage", "Vault"],
  "edges": [["Internet Gateway", "lb"], ["lb", "VM Instance 1"], ["VM Instance 1", "db"]]
}
```

形式の詳細 → `reference/spec-format.md`
配置の考え方 → `reference/layout-rules.md`

### 3. 生成して検証する

```bash
python3 scripts/build_drawio.py spec.json -o output.drawio
python3 scripts/validate_drawio.py output.drawio
```

`validate_drawio.py` が `[OK]` を返すまで直す。警告を残したまま渡さない。

### 4. 設計ポイントを解説する（必須）

図を渡して終わりにせず、設計判断をテキストで説明する。
形式 → `reference/explanation.md`

---

## 手順: 既存ファイルの編集

1. `.drawio` を XML として読む
2. `<mxCell>` を追加・変更・削除する（`reference/xml-spec.md`）
3. `python3 scripts/validate_drawio.py target.drawio` で検証する
4. 設計ポイントの変更点を説明する

既にファイル内にある `style` 文字列はそのまま再利用する。新しいアイコンを足すときだけ
`components/{カテゴリ}.json` から `style` をコピーする。**SVG を自分で埋め込まない。**

大幅な作り直しになる場合は、スペックを書き起こして `build_drawio.py` で作り直す方が速い。

---

## 手順: AWS / Azure からの変換

1. 元の構成図（画像・XML・説明文）から構成要素と接続を読み取る
2. `reference/cloud-mapping.md` で OCI のコンポーネントに対応づける
3. 上記「新規作成」の手順で図を作る
4. 解説には **サービスマッピング表** と **差異・注意点** を必ず含める
   （`reference/explanation.md`）

---

## ファイル構成

| パス | 内容 |
|---|---|
| `scripts/build_drawio.py` | スペック → `.drawio` |
| `scripts/validate_drawio.py` | `.drawio` の検証 |
| `scripts/oci_components.py` | コンポーネント名の解決（単体でも実行可） |
| `components/index.json` | 名前 → カテゴリ（8KB） |
| `components/aliases.json` | 別名・略称 → 正式名 |
| `components/{カテゴリ}.json` | style を含む定義（必要なカテゴリだけ読む） |
| `reference/spec-format.md` | スペック形式 |
| `reference/xml-spec.md` | draw.io XML 仕様（手編集用） |
| `reference/layout-rules.md` | 配置・座標の規則 |
| `reference/cloud-mapping.md` | AWS/Azure → OCI 対応表 |
| `reference/explanation.md` | 設計ポイント解説の形式 |
| `reference/component-list.md` | コンポーネント一覧（自動生成） |
| `examples/specs/*.json` | サンプルのスペック |
| `examples/*.drawio` | サンプルの出力 |
| `templates/base_diagram.drawio` | 手編集用の雛形 |
| `setup.sh` | アイコンの再取得（任意。同梱済みなので通常は不要） |

## 出力

- 拡張子は `.drawio`
- 保存先はカレントディレクトリ、または指示された場所
- [draw.io デスクトップ版](https://github.com/jgraph/drawio-desktop) / [Web版](https://app.diagrams.net/) でそのまま開ける
