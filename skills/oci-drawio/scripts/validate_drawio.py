#!/usr/bin/env python3
"""生成した .drawio を検証する。

draw.io で開く前に、機械的に検出できる壊れ方をすべて潰すためのスクリプト。
構成図を生成・編集したら必ず実行すること。

使い方:
    python3 scripts/validate_drawio.py out.drawio
    python3 scripts/validate_drawio.py examples/*.drawio

終了コード: 0 = エラーなし / 1 = エラーあり
"""

import argparse
import base64
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from oci_components import Components  # noqa: E402

SIZE_WARN_KB = 400  # これを超えると draw.io の動作が重くなりやすい


class Report:
    def __init__(self, path):
        self.path = path
        self.errors = []
        self.warnings = []

    def error(self, msg):
        self.errors.append(msg)

    def warn(self, msg):
        self.warnings.append(msg)

    def print(self):
        size_kb = Path(self.path).stat().st_size / 1024
        status = "NG" if self.errors else ("WARN" if self.warnings else "OK")
        print(f"[{status}] {self.path} ({size_kb:.0f}KB)")
        for msg in self.errors:
            print(f"  ERROR: {msg}")
        for msg in self.warnings:
            print(f"  WARN:  {msg}")
        return not self.errors


def _geom(cell):
    g = cell.find("mxGeometry")
    if g is None:
        return None
    try:
        return (
            float(g.get("x", 0)), float(g.get("y", 0)),
            float(g.get("width", 0)), float(g.get("height", 0)),
        )
    except ValueError:
        return None


def validate(path, comps, known_styles):
    report = Report(path)

    # 1. XML として妥当か
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as e:
        report.error(f"XML を解析できません: {e}")
        return report

    cells = root.findall(".//mxCell")
    if not cells:
        report.error("mxCell が 1 つもありません")
        return report

    ids = {}
    for cell in cells:
        cid = cell.get("id")
        if cid is None:
            report.error("id を持たない mxCell があります")
            continue
        if cid in ids:
            report.error(f"id が重複しています: {cid!r}")
        ids[cid] = cell

    # 2. parent が実在するか
    for cid, cell in ids.items():
        parent = cell.get("parent")
        if parent is not None and parent not in ids:
            report.error(f"{cid!r} の parent={parent!r} が存在しません")

    # 3. edge の source / target が実在するか
    for cid, cell in ids.items():
        if cell.get("edge") != "1":
            continue
        for attr in ("source", "target"):
            ref = cell.get(attr)
            if ref is None:
                report.warn(f"edge {cid!r} に {attr} がありません（浮いた線になります）")
            elif ref not in ids:
                report.error(f"edge {cid!r} の {attr}={ref!r} が存在しません")

    # 4〜6. アイコンのスタイルとデータ URI
    icon_count = 0
    for cid, cell in ids.items():
        style = cell.get("style") or ""
        if "shape=image" not in style:
            continue
        icon_count += 1

        if "data:image/svg+xml;base64," in style:
            report.error(
                f"{cid!r} が壊れたデータURI形式を使っています "
                "(';base64' は draw.io のスタイル区切りと衝突します)。"
                "'data:image/svg+xml,' を使ってください"
            )
            continue

        m = re.search(r"image=data:image/svg\+xml,([^;]+)", style)
        if not m:
            report.error(f"{cid!r} の style に有効な image=data:image/svg+xml, がありません")
            continue

        payload = m.group(1)
        try:
            svg = base64.b64decode(payload, validate=True).decode("utf-8")
        except Exception as e:
            report.error(f"{cid!r} の base64 をデコードできません（切れている可能性）: {e}")
            continue
        if not svg.lstrip().startswith("<svg") or not svg.rstrip().endswith("</svg>"):
            report.error(f"{cid!r} の SVG が <svg>…</svg> で閉じていません（出力が途中で切れています）")

        if style not in known_styles:
            report.warn(
                f"{cid!r} のアイコンが components 辞書のスタイルと一致しません"
                "（改変されたか、辞書に無いアイコンです）"
            )

    if icon_count == 0:
        report.warn("アイコン (shape=image) が 1 つもありません")

    # 7. 子要素が親コンテナからはみ出していないか
    for cid, cell in ids.items():
        parent = cell.get("parent")
        if parent in (None, "0", "1") or parent not in ids:
            continue
        child, box = _geom(cell), _geom(ids[parent])
        if child is None or box is None:
            continue
        x, y, w, h = child
        _, _, pw, ph = box
        if pw == 0 or ph == 0:
            continue
        # ゲートウェイは意図的に枠線へ跨がらせるので、はみ出し半分までは許容する
        tolerance = w / 2
        if x < -tolerance or y < -tolerance or x + w > pw + tolerance or y + h > ph + tolerance:
            report.warn(
                f"{cid!r} が親 {parent!r} からはみ出しています "
                f"(x={x:g}, y={y:g}, w={w:g}, h={h:g} / 親 {pw:g}x{ph:g})"
            )

    # 8. 同じ親の中でアイコンが重なっていないか
    siblings = {}
    for cid, cell in ids.items():
        if "shape=image" not in (cell.get("style") or ""):
            continue
        g = _geom(cell)
        if g:
            siblings.setdefault(cell.get("parent"), []).append((cid, g))
    for parent, items in siblings.items():
        for i, (a_id, a) in enumerate(items):
            for b_id, b in items[i + 1:]:
                if (a[0] < b[0] + b[2] and b[0] < a[0] + a[2]
                        and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]):
                    report.warn(f"{a_id!r} と {b_id!r} が重なっています（親 {parent!r}）")

    # 9. 接続線が無関係なアイコンを貫通していないか
    def _abs(cid, seen=()):
        cell = ids[cid]
        g = _geom(cell)
        if g is None:
            return None
        parent = cell.get("parent")
        if parent in (None, "0", "1") or parent not in ids or parent in seen:
            return g
        pg = _abs(parent, seen + (cid,))
        return (g[0] + pg[0], g[1] + pg[1], g[2], g[3]) if pg else g

    boxes = {
        cid: _abs(cid)
        for cid, cell in ids.items()
        if "shape=image" in (cell.get("style") or "") and _abs(cid)
    }
    for cid, cell in ids.items():
        if cell.get("edge") != "1":
            continue
        src, dst = cell.get("source"), cell.get("target")
        if src not in boxes or dst not in boxes:
            continue
        style = cell.get("style") or ""

        def anchor(box, kind):
            mx = re.search(rf"{kind}X=([\d.]+)", style)
            my = re.search(rf"{kind}Y=([\d.]+)", style)
            fx = float(mx.group(1)) if mx else 0.5
            fy = float(my.group(1)) if my else 0.5
            return box[0] + box[2] * fx, box[1] + box[3] * fy

        way = [
            (float(p.get("x", 0)), float(p.get("y", 0)))
            for p in cell.findall('.//Array[@as="points"]/mxPoint')
        ]
        pts = [anchor(boxes[src], "exit")] + way + [anchor(boxes[dst], "entry")]
        for other, (bx, by, bw, bh) in boxes.items():
            if other in (src, dst):
                continue
            for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
                # 斜めの線分は draw.io 側で直交に引き直されるため判定しない
                if abs(x1 - x2) > 1 and abs(y1 - y2) > 1:
                    continue
                if (min(x1, x2) < bx + bw and bx < max(x1, x2)
                        and min(y1, y2) < by + bh and by < max(y1, y2)):
                    report.warn(f"接続線 {cid!r} が {other!r} を貫通しています")
                    break
            else:
                continue
            break

    # 10. ファイルサイズ
    size_kb = Path(path).stat().st_size / 1024
    if size_kb > SIZE_WARN_KB:
        report.warn(
            f"{size_kb:.0f}KB は大きすぎます（目安 {SIZE_WARN_KB}KB）。"
            "アイコン数を減らすか図を分割してください"
        )

    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("files", nargs="+", help="検証する .drawio")
    parser.add_argument("--components-dir", default=None)
    args = parser.parse_args(argv)

    comps = Components(args.components_dir) if args.components_dir else Components()
    known_styles = comps.all_styles()

    ok = True
    for path in args.files:
        if not Path(path).exists():
            print(f"[NG] {path} (ファイルがありません)")
            ok = False
            continue
        ok &= validate(path, comps, known_styles).print()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
