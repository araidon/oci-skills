# スペック形式（build_drawio.py）

`scripts/build_drawio.py` が読む JSON / YAML の形式。

```bash
python3 scripts/build_drawio.py spec.json -o out.drawio
python3 scripts/validate_drawio.py out.drawio
```

スペックは 1〜2KB 程度。base64 アイコン・座標・XML はスクリプトが組み立てるので、
書く必要はない。

---

## 全体構造

```json
{
  "title": "図のタイトル",
  "region": "Japan East (Tokyo)",
  "external": ["On-Premises Data Center"],
  "vcn": {
    "label": "VCN (10.0.0.0/16)",
    "gateways": { "left": [...], "right": [...] },
    "subnets": [ { "label": "...", "nodes": [...] } ]
  },
  "regional_services": ["Object Storage", "Vault"],
  "edges": [["from", "to"]]
}
```

| キー | 必須 | 内容 |
|---|---|---|
| `title` | 任意 | draw.io のタブ名。既定 `OCI Architecture` |
| `region` | 任意 | Region ボックスのラベル |
| `external` | 任意 | Region の外に置くもの（オンプレ、インターネット等） |
| `vcn.label` | 任意 | VCN ボックスのラベル。CIDR を書くとよい |
| `vcn.gateways.left` | 任意 | VCN 左枠線に跨がらせるゲートウェイ（IGW / NAT / DRG） |
| `vcn.gateways.right` | 任意 | VCN 右枠線に跨がらせるゲートウェイ（SGW） |
| `vcn.subnets` | 任意 | 上から順に縦に積まれる。VCN 幅いっぱいに広がる |
| `regional_services` | 任意 | VCN の外・Region の中（右側の列） |
| `edges` | 任意 | 接続線 |

`vcn.gateways` はリストで書くと全て左辺に置かれる。

---

## ノードの書き方

3通りある。どこでも（subnets / gateways / regional_services / external）同じ。

```json
"nodes": [
  "Load Balancer",
  "VM Instance x3",
  { "component": "Autonomous Database", "label": "本番DB", "id": "db", "count": 2 }
]
```

| 形式 | 意味 |
|---|---|
| `"Load Balancer"` | 1 個 |
| `"VM Instance x3"` | 3 個。ラベルは `VM Instance 1` … `VM Instance 3` |
| オブジェクト | 下表のとおり |

| フィールド | 内容 |
|---|---|
| `component` | 必須。コンポーネント名（別名・略称可） |
| `label` | 図に表示する文字。既定はコンポーネント名 |
| `id` | `edges` から参照する ID。既定はラベルから自動生成 |
| `count` | 個数。2以上なら `id` は `db-1` `db-2` … になる |

`component` は `components/index.json` の正式名のほか、`components/aliases.json` の
別名・略称（`VPC` `IGW` `ADB` `OSS` `KMS` `Kubernetes` など）や部分一致でも解決できる。
解決できない場合はエラーになり、近い候補が表示される。

```bash
python3 scripts/oci_components.py "kubernetes" "ADB" "オブジェクトストレージ"
```

---

## 接続線の書き方

```json
"edges": [
  ["Internet Gateway", "lb"],
  ["lb", "app-1"],
  { "from": "app-1", "to": "db" }
]
```

端点は次の順で解決される。

1. ノードの `id`
2. ノードの `label`
3. コンポーネント名（図の中で1個しかない場合のみ）

同じコンポーネントが複数ある場合は `id` を明示すること。曖昧なままだと
エラーになり、候補の ID が表示される。

線の引き方（どの辺から出てどこで曲がるか）は指定しない。2つの図形の位置関係から、
縦配線・横配線のうち **他のアイコンを貫通しない方** が自動で選ばれ、直交＋角丸で
描かれる。詳細は `reference/layout-rules.md`。

---

## 例

`examples/specs/` に実際に使っているスペックがある。

- `basic-web-3tier.json` — LB + Web/App × 3 + Autonomous Database
- `ha-architecture.json` — WAF、内部LB、Web/App 冗長化、Data Guard、オンプレ接続

---

## レイアウトの調整

座標はスクリプトが自動計算する。細かい位置調整が必要なときは、生成した
`.drawio` の `mxGeometry` を直接編集する（`reference/xml-spec.md` 参照）。
編集後は必ず `validate_drawio.py` を通すこと。

主な定数は `scripts/build_drawio.py` の冒頭にある。

| 定数 | 既定 | 意味 |
|---|---|---|
| `ICON` | 60 | アイコン一辺 |
| `ICON_GAP_X` | 100 | アイコン間の余白（中心間 160px） |
| `MAX_COLS` | 5 | 1行に並べる上限。超えたら折り返す |
| `GW_STEP_Y` | 120 | ゲートウェイの縦間隔 |
| `VCN_PAD_LEFT_WITH_GW` | 60 | 左枠線にGWがあるときの VCN 左内側 |
| `EDGE_GUTTER` | 20 | 接続線の折れ点を図形から離す距離 |
