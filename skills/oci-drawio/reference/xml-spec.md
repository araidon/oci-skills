# draw.io XML 仕様（既存ファイルの編集用）

新規作成は `scripts/build_drawio.py` を使う（`reference/spec-format.md`）。
このファイルは **既存の `.drawio` を直接編集する** ときの参照。

編集後は必ず検証すること。

```bash
python3 scripts/validate_drawio.py target.drawio
```

---

## ファイル構造

```xml
<mxfile host="app.diagrams.net" type="device">
  <diagram id="oci-diagram-1" name="OCI Architecture">
    <mxGraphModel dx="1024" dy="768" grid="1" gridSize="10" guides="1" tooltips="1"
                  connect="1" arrows="1" fold="1" page="1" pageScale="1"
                  pageWidth="1600" pageHeight="900" math="0" shadow="0">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        <!-- ここに要素を並べる -->
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

`templates/base_diagram.drawio` に Region / VCN / Subnet だけの雛形がある。

---

## 要素の種類

**コンテナ（Region / VCN / Subnet）**

```xml
<mxCell id="region-1" value="Japan East (Tokyo)" style="..." vertex="1" parent="1">
  <mxGeometry x="20" y="20" width="1200" height="700" as="geometry"/>
</mxCell>
```

**アイコン（サービス）**

```xml
<mxCell id="lb-1" value="Load Balancer" style="{components から取得}" vertex="1" parent="subnet-1">
  <mxGeometry x="20" y="40" width="60" height="60" as="geometry"/>
</mxCell>
```

**接続線**

```xml
<mxCell id="conn-1"
        style="endArrow=none;startArrow=none;strokeColor=#000000;strokeWidth=1;edgeStyle=orthogonalEdgeStyle;rounded=1;arcSize=8;jettySize=20;orthogonalLoop=1;html=1;exitX=0.5;exitY=1;exitDx=0;exitDy=0;entryX=0.5;entryY=0;entryDx=0;entryDy=0;"
        edge="1" source="lb-1" target="app-1" parent="1">
  <mxGeometry relative="1" as="geometry">
    <Array as="points">
      <mxPoint x="150" y="250"/>
      <mxPoint x="310" y="250"/>
    </Array>
  </mxGeometry>
</mxCell>
```

接続線の `parent` は常に `1`（ルート）。折れ点（`<Array as="points">`）の座標も
ルート基準の絶対座標で書く。

出入口を `exitX/exitY`・`entryX/entryY` で固定しないと、draw.io が意図しない辺から
線を出し、間にあるアイコンを貫通することがある。配置の指針は
`reference/layout-rules.md` を参照。

---

## 親子関係と座標

`mxGeometry` の `x` / `y` は **親コンテナからの相対座標**。

| 要素 | parent |
|---|---|
| Region | `1` |
| VCN | `region-1` |
| Subnet | `vcn-1` |
| Subnet 内のアイコン | `subnet-1` |
| VCN 枠線上のゲートウェイ | `vcn-1`（`x=-30` で左枠線に跨がる） |
| Region 内・VCN 外のサービス | `region-1` |
| 接続線 | `1` |

---

## アイコンのスタイル（重要）

アイコンの `style` は `components/{カテゴリ}.json` の `style` を**そのままコピーする**。
SVG を自分で埋め込んだり base64 を作り直したりしないこと。

```python
import json
comps = json.load(open("components/networking.json"))
style = comps["Load Balancer"]["style"]
```

### データ URI の形式

draw.io は `;` をスタイルの区切りに使うため、標準的な
`data:image/svg+xml;base64,XXXX` は **`;base64` の位置で切れて画像が壊れる**。

```
正: image=data:image/svg+xml,XXXX
誤: image=data:image/svg+xml;base64,XXXX
```

`components/*.json` は正しい形式で格納されている。手で組み立てないこと。
（この形式ミスで examples 2件が長期間壊れていた。validate_drawio.py が検出する）

### サイズの実態

Oracle 公式アイコンは1つあたり **中央値 4,177 文字**、最大 286,555 文字
（`Logic Flow`）。234件中233件が1,000文字を超える。

- アイコン10個で style だけで約 50KB
- 手書きで XML を書くと出力トークン上限に達し、途中で切れた `.drawio` ができる
- **アイコンを10個以上使う図は `build_drawio.py` を使うこと**

既存ファイルの編集時は、既にファイル内にある style 文字列を再利用すれば
新たに出力する必要はない。

---

## コンテナのスタイル

**Region**（実線グレー・白背景）

```
rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#878787;fillColor=#FFFFFF;dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontStyle=1;fontSize=14;fontColor=#000000;
```

**VCN**（破線オレンジ・透明）

```
rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#D04A02;fillColor=none;dashed=1;dashPattern=8 4;verticalAlign=top;align=left;spacingLeft=10;fontStyle=1;fontSize=12;fontColor=#D04A02;
```

**Subnet**（破線オレンジ・透明、Public/Private はラベルで区別）

```
rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#D04A02;fillColor=none;dashed=1;dashPattern=8 4;verticalAlign=top;align=left;spacingLeft=10;fontSize=11;fontColor=#D04A02;
```

これらは `scripts/build_drawio.py` の `STYLE_REGION` / `STYLE_VCN` / `STYLE_SUBNET`
と同一。
