#!/usr/bin/env python3
"""index.json から コンポーネント一覧の Markdown を生成する。

カテゴリ表を手書きすると実データとすぐズレるため（実際に13件のズレが放置されていた）、
常にここから生成する。

    python3 scripts/gen_component_list.py > reference/component-list.md
"""

import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from oci_components import Components  # noqa: E402

CATEGORY_LABEL = {
    "networking": "Networking",
    "compute": "Compute",
    "database": "Database",
    "storage": "Storage",
    "security": "Identity & Security",
    "developer": "Developer Services（コンテナ含む）",
    "monitoring": "Observability & Management",
    "ai": "Analytics & AI",
    "applications": "Applications",
    "governance": "Governance",
    "hybrid": "Hybrid / Multicloud",
    "migration": "Migration",
    "general": "General",
}


def main():
    comps = Components()
    by_cat = defaultdict(list)
    for name, cat in comps.index.items():
        by_cat[cat].append(name)

    out = [
        "# コンポーネント一覧",
        "",
        "> このファイルは `scripts/gen_component_list.py` が `components/index.json` から",
        "> 生成する。手で編集しないこと。",
        "",
        f"全 {len(comps.index)} コンポーネント / {len(by_cat)} カテゴリ / "
        f"別名 {len(comps.aliases)} 件（`components/aliases.json`）",
        "",
        "コンポーネント名は `components/{カテゴリ}.json` のキーと一致する。",
        "名前の解決には別名・略称・部分一致も使えるので、",
        "`python3 scripts/oci_components.py \"<名前>\"` で確認できる。",
        "",
        "| カテゴリ | ファイル | 件数 | コンポーネント |",
        "|---|---|---|---|",
    ]
    for cat in sorted(by_cat):
        names = sorted(by_cat[cat])
        label = CATEGORY_LABEL.get(cat, cat)
        out.append(
            f"| **{label}** | `components/{cat}.json` | {len(names)} | "
            + ", ".join(names)
            + " |"
        )

    out += [
        "",
        "## 主な別名",
        "",
        "`components/aliases.json` により、以下のような呼び方でも解決できる。",
        "",
        "| 入力 | 解決先 |",
        "|---|---|",
    ]
    highlights = [
        "VPC", "IGW", "NAT", "SGW", "LB", "NLB", "ADB", "ATP", "ADW",
        "OSS", "FSS", "KMS", "Kubernetes", "Container Registry",
        "Virtual Machine", "Site-to-Site VPN", "Compartment",
    ]
    for alias in highlights:
        if alias in comps.aliases:
            out.append(f"| `{alias}` | {comps.aliases[alias]} |")
    out.append("")
    print("\n".join(out))


if __name__ == "__main__":
    main()
