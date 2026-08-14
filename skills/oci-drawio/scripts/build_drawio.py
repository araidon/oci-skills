#!/usr/bin/env python3
"""スペック(JSON/YAML) から OCI 構成図の .drawio を生成する。

Claude はコンパクトなスペックだけを書き、base64 アイコンの埋め込み・座標計算・
XML 組み立てはこのスクリプトが行う。これにより出力トークンを 20〜30 分の 1 に抑え、
XML 破損や base64 切れを構造的に防ぐ。

使い方:
    python3 scripts/build_drawio.py spec.json -o out.drawio
    python3 scripts/build_drawio.py spec.yaml -o out.drawio
    cat spec.json | python3 scripts/build_drawio.py - -o out.drawio

スペックの形式は reference/spec-format.md を参照。
"""

import argparse
import json
import re
import sys
from pathlib import Path
from xml.sax.saxutils import quoteattr

sys.path.insert(0, str(Path(__file__).resolve().parent))
from oci_components import Components, ComponentNotFound  # noqa: E402

# ── レイアウト定数（reference/layout-rules.md と対応）──────────────
ICON = 60               # アイコン一辺
ICON_GAP_X = 100        # アイコン間の余白（中心間 160px）
ICON_STEP_X = ICON + ICON_GAP_X
ROW_STEP_Y = 110        # 段組みしたときの行送り（アイコン+ラベル+余白）
MAX_COLS = 5            # これを超えたら折り返す

SUBNET_PAD_X = 20
SUBNET_LABEL_H = 40     # サブネット名のための上部余白
SUBNET_BOTTOM_PAD = 40  # アイコン下ラベルのための下部余白
SUBNET_GAP_Y = 20

VCN_PAD = 20
VCN_LABEL_H = 40
VCN_MIN_W = 500

REGION_PAD = 20
REGION_LABEL_H = 40

GW_START_Y = 80         # VCN 枠線上の最初のゲートウェイ
GW_STEP_Y = 120
SERVICE_COL_GAP = 60    # VCN 右端から地域サービス列までの距離
SERVICE_COL_W = 160

STYLE_REGION = (
    "rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#878787;fillColor=#FFFFFF;"
    "dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontStyle=1;fontSize=14;"
    "fontColor=#000000;"
)
STYLE_VCN = (
    "rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#D04A02;fillColor=none;"
    "dashed=1;dashPattern=8 4;verticalAlign=top;align=left;spacingLeft=10;fontStyle=1;"
    "fontSize=12;fontColor=#D04A02;"
)
STYLE_SUBNET = (
    "rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#D04A02;fillColor=none;"
    "dashed=1;dashPattern=8 4;verticalAlign=top;align=left;spacingLeft=10;fontSize=11;"
    "fontColor=#D04A02;"
)
STYLE_EDGE = (
    "endArrow=none;startArrow=none;strokeColor=#000000;strokeWidth=1;"
    "edgeStyle=orthogonalEdgeStyle;"
)


class SpecError(ValueError):
    pass


# ── スペックの正規化 ──────────────────────────────────────────────
def _slug(text):
    s = re.sub(r"[^a-z0-9]+", "-", str(text).lower()).strip("-")
    return s or "node"


def _parse_node(raw):
    """ノード指定を dict に正規化する。

    受け付ける形:
        "Load Balancer"                 -> 1 個
        "VM Instance x3"                -> 3 個
        {"component": "...", "label": "...", "id": "...", "count": 2}
    """
    if isinstance(raw, str):
        m = re.match(r"^(.*?)\s*[x*]\s*(\d+)$", raw.strip())
        if m:
            return {"component": m.group(1).strip(), "count": int(m.group(2))}
        return {"component": raw.strip(), "count": 1}
    if isinstance(raw, dict):
        node = dict(raw)
        if "component" not in node:
            raise SpecError(f"ノードに component がありません: {raw!r}")
        node["count"] = int(node.get("count", 1))
        return node
    raise SpecError(f"ノードの指定が不正です: {raw!r}")


def _expand(raw_nodes):
    """ノード指定のリストを 1 個ずつに展開する。"""
    out = []
    for raw in raw_nodes or []:
        node = _parse_node(raw)
        count = node.pop("count", 1)
        for i in range(count):
            item = dict(node)
            if count > 1:
                base = item.get("label", item["component"])
                item["label"] = f"{base} {i + 1}"
                if "id" in item:
                    item["id"] = f"{item['id']}-{i + 1}"
            out.append(item)
    return out


# ── 図の組み立て ──────────────────────────────────────────────────
class DiagramBuilder:
    def __init__(self, spec, components):
        self.spec = spec
        self.comps = components
        self.cells = []          # (id, value, style, x, y, w, h, parent)
        self.edges = []          # (id, source, target)
        self.nodes = {}          # id -> {"label":..., "component":...}
        self._used_ids = set()

    # -- id 採番 --
    def _new_id(self, preferred):
        base = _slug(preferred)
        candidate = base
        n = 2
        while candidate in self._used_ids:
            candidate = f"{base}-{n}"
            n += 1
        self._used_ids.add(candidate)
        return candidate

    def _add_container(self, cid, label, style, x, y, w, h, parent):
        self._used_ids.add(cid)
        self.cells.append((cid, label, style, x, y, w, h, parent))
        return cid

    def _add_icon(self, node, x, y, parent):
        component = node["component"]
        try:
            canonical = self.comps.resolve(component)
        except ComponentNotFound as e:
            raise SpecError(str(e)) from None
        label = node.get("label", canonical)
        cid = self._new_id(node.get("id") or label)
        style = self.comps.style(canonical)
        self.cells.append((cid, label, style, x, y, ICON, ICON, parent))
        self.nodes[cid] = {"label": label, "component": canonical}
        return cid

    # -- 端点解決 --
    def _resolve_endpoint(self, ref):
        if ref in self.nodes or ref in self._used_ids:
            return ref
        by_label = [i for i, n in self.nodes.items() if n["label"] == ref]
        if len(by_label) == 1:
            return by_label[0]
        by_component = [i for i, n in self.nodes.items() if n["component"] == ref]
        if len(by_component) == 1:
            return by_component[0]
        try:
            canonical = self.comps.resolve(ref)
        except ComponentNotFound:
            canonical = None
        if canonical:
            match = [i for i, n in self.nodes.items() if n["component"] == canonical]
            if len(match) == 1:
                return match[0]
        ambiguous = by_label or by_component
        if ambiguous:
            raise SpecError(
                f"edge の端点 {ref!r} が複数のノードに一致します: {ambiguous}。"
                " スペックで id を明示してください。"
            )
        raise SpecError(
            f"edge の端点が見つかりません: {ref!r}。"
            f" 使えるのは: {sorted(self.nodes)}"
        )

    # -- レイアウト --
    def build(self):
        spec = self.spec
        vcn_spec = spec.get("vcn") or {}
        subnets = vcn_spec.get("subnets") or []

        subnet_nodes = [_expand(s.get("nodes")) for s in subnets]
        gw_spec = vcn_spec.get("gateways") or {}
        if isinstance(gw_spec, list):        # 省略形: すべて左辺に置く
            gw_spec = {"left": gw_spec}
        left_gws = _expand(gw_spec.get("left"))
        right_gws = _expand(gw_spec.get("right"))
        services = _expand(spec.get("regional_services"))
        externals = _expand(spec.get("external"))

        # 幅: 最も横に長いサブネットに合わせる
        max_cols = max([min(len(n), MAX_COLS) for n in subnet_nodes] or [1])
        subnet_w = max(
            VCN_MIN_W - 2 * VCN_PAD,
            2 * SUBNET_PAD_X + max_cols * ICON + (max_cols - 1) * ICON_GAP_X,
        )
        vcn_w = subnet_w + 2 * VCN_PAD

        # 高さ: 各サブネットの段数から算出
        subnet_heights = []
        for nodes in subnet_nodes:
            rows = max(1, -(-len(nodes) // MAX_COLS))
            subnet_heights.append(
                SUBNET_LABEL_H + rows * ICON + (rows - 1) * (ROW_STEP_Y - ICON)
                + SUBNET_BOTTOM_PAD
            )
        content_h = sum(subnet_heights) + max(0, len(subnets) - 1) * SUBNET_GAP_Y
        vcn_h = max(
            VCN_LABEL_H + content_h + VCN_PAD,
            GW_START_Y + max(len(left_gws), len(right_gws)) * GW_STEP_Y,
            200,
        )

        service_col_w = SERVICE_COL_GAP + SERVICE_COL_W if services else 0
        region_w = REGION_PAD + vcn_w + service_col_w + REGION_PAD
        region_h = max(
            REGION_LABEL_H + vcn_h + REGION_PAD,
            REGION_LABEL_H + GW_START_Y + len(services) * GW_STEP_Y,
        )

        # 図体の外側（オンプレ・インターネットなど）は Region の左に置く
        ext_w = (SERVICE_COL_W if externals else 0)
        origin_x = 20 + (ext_w + 40 if externals else 0)

        region_id = self._add_container(
            "region-1", spec.get("region", "Region"), STYLE_REGION,
            origin_x, 20, region_w, region_h, "1",
        )
        vcn_id = self._add_container(
            "vcn-1", vcn_spec.get("label", "VCN"), STYLE_VCN,
            REGION_PAD, REGION_LABEL_H, vcn_w, vcn_h, region_id,
        )

        y = VCN_LABEL_H
        for n, (spec_subnet, nodes, height) in enumerate(
            zip(subnets, subnet_nodes, subnet_heights), start=1
        ):
            sid = self._add_container(
                self._new_id(spec_subnet.get("id") or f"subnet-{n}"),
                spec_subnet.get("label", "Subnet"), STYLE_SUBNET,
                VCN_PAD, y, subnet_w, height, vcn_id,
            )
            for i, node in enumerate(nodes):
                col, row = i % MAX_COLS, i // MAX_COLS
                self._add_icon(
                    node,
                    SUBNET_PAD_X + col * ICON_STEP_X,
                    SUBNET_LABEL_H + row * ROW_STEP_Y,
                    sid,
                )
            y += height + SUBNET_GAP_Y

        # ゲートウェイは VCN の枠線に跨がらせる
        for i, gw in enumerate(left_gws):
            self._add_icon(gw, -ICON // 2, GW_START_Y + i * GW_STEP_Y, vcn_id)
        for i, gw in enumerate(right_gws):
            self._add_icon(gw, vcn_w - ICON // 2, GW_START_Y + i * GW_STEP_Y, vcn_id)

        # 地域サービスは VCN の右、Region の内側
        for i, svc in enumerate(services):
            self._add_icon(
                svc,
                REGION_PAD + vcn_w + SERVICE_COL_GAP,
                REGION_LABEL_H + GW_START_Y + i * GW_STEP_Y,
                region_id,
            )

        # 外部要素は Region の外（ルート直下）
        for i, ext in enumerate(externals):
            self._add_icon(ext, 20, 20 + REGION_LABEL_H + i * GW_STEP_Y, "1")

        for i, edge in enumerate(spec.get("edges") or [], start=1):
            if isinstance(edge, dict):
                src, dst = edge["from"], edge["to"]
            else:
                src, dst = edge[0], edge[1]
            self.edges.append(
                (f"conn-{i}", self._resolve_endpoint(src), self._resolve_endpoint(dst))
            )

        return region_w + origin_x + 100, region_h + 120

    # -- XML 出力 --
    def to_xml(self, page_w, page_h, title):
        parts = [
            '<mxfile host="app.diagrams.net" type="device">',
            f'  <diagram id="oci-diagram-1" name={quoteattr(title)}>',
            f'    <mxGraphModel dx="1024" dy="768" grid="1" gridSize="10" guides="1" '
            f'tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" '
            f'pageWidth="{page_w}" pageHeight="{page_h}" math="0" shadow="0">',
            "      <root>",
            '        <mxCell id="0"/>',
            '        <mxCell id="1" parent="0"/>',
        ]
        for cid, value, style, x, y, w, h, parent in self.cells:
            parts.append(
                f"        <mxCell id={quoteattr(cid)} value={quoteattr(value)} "
                f"style={quoteattr(style)} vertex=\"1\" parent={quoteattr(parent)}>"
            )
            parts.append(
                f'          <mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" '
                f'as="geometry"/>'
            )
            parts.append("        </mxCell>")
        for eid, src, dst in self.edges:
            parts.append(
                f"        <mxCell id={quoteattr(eid)} style={quoteattr(STYLE_EDGE)} "
                f"edge=\"1\" source={quoteattr(src)} target={quoteattr(dst)} "
                f'parent="1">'
            )
            parts.append('          <mxGeometry relative="1" as="geometry"/>')
            parts.append("        </mxCell>")
        parts += ["      </root>", "    </mxGraphModel>", "  </diagram>", "</mxfile>", ""]
        return "\n".join(parts)


def load_spec(path):
    text = sys.stdin.read() if path == "-" else Path(path).read_text(encoding="utf-8")
    if path != "-" and Path(path).suffix in (".yaml", ".yml"):
        import yaml

        return yaml.safe_load(text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        try:
            import yaml
        except ImportError:
            raise
        return yaml.safe_load(text)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("spec", help="スペックファイル (.json / .yaml)。'-' で標準入力")
    parser.add_argument("-o", "--output", required=True, help="出力する .drawio")
    parser.add_argument("--components-dir", default=None, help="components/ の場所")
    args = parser.parse_args(argv)

    spec = load_spec(args.spec)
    if not isinstance(spec, dict):
        print("ERROR: スペックはオブジェクト(dict)である必要があります", file=sys.stderr)
        return 1

    comps = (
        Components(args.components_dir) if args.components_dir else Components()
    )
    builder = DiagramBuilder(spec, comps)
    try:
        page_w, page_h = builder.build()
    except SpecError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    xml = builder.to_xml(page_w, page_h, spec.get("title", "OCI Architecture"))
    out = Path(args.output)
    out.write_text(xml, encoding="utf-8")
    print(
        f"Generated: {out} "
        f"({len(builder.cells)} cells, {len(builder.edges)} edges, "
        f"{out.stat().st_size / 1024:.0f}KB)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
