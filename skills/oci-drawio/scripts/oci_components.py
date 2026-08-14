#!/usr/bin/env python3
"""OCI コンポーネント辞書のロードと名前解決。

build_drawio.py / validate_drawio.py の共通モジュール。

名前解決は以下の順に試みる:
  1. index.json の正式名と完全一致
  2. aliases.json の別名と完全一致
  3. 記号・空白・大小文字を無視した正規化一致（正式名 → 別名の順）
  4. 正規化した前方一致 / 部分一致（候補が1件に絞れる場合のみ）
"""

import json
import re
from pathlib import Path

COMPONENTS_DIR = Path(__file__).resolve().parent.parent / "components"


class ComponentNotFound(LookupError):
    """コンポーネント名を解決できなかった。candidates に近い候補を持つ。"""

    def __init__(self, name, candidates=None):
        self.name = name
        self.candidates = candidates or []
        msg = f"コンポーネントが見つかりません: {name!r}"
        if self.candidates:
            msg += "\n  もしかして: " + ", ".join(repr(c) for c in self.candidates[:8])
        super().__init__(msg)


def _norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


class Components:
    """コンポーネント辞書。カテゴリファイルは必要になった時点で読み込む。"""

    def __init__(self, components_dir=COMPONENTS_DIR):
        self.dir = Path(components_dir)
        index_path = self.dir / "index.json"
        if not index_path.exists():
            raise FileNotFoundError(
                f"{index_path} がありません。setup.sh を実行してアイコンを生成してください。"
            )
        self.index = json.load(open(index_path, encoding="utf-8"))
        self.index.pop("_comment", None)

        aliases_path = self.dir / "aliases.json"
        self.aliases = {}
        if aliases_path.exists():
            raw = json.load(open(aliases_path, encoding="utf-8"))
            self.aliases = {k: v for k, v in raw.items() if not k.startswith("_")}

        self._norm_index = {_norm(k): k for k in self.index}
        self._norm_aliases = {_norm(k): v for k, v in self.aliases.items()}
        self._cat_cache = {}

    # ── 名前解決 ────────────────────────────────────────────────
    def resolve(self, name):
        """入力名を index.json の正式名に解決する。失敗時 ComponentNotFound。"""
        if name in self.index:
            return name
        if name in self.aliases:
            return self.aliases[name]

        key = _norm(name)
        if key in self._norm_index:
            return self._norm_index[key]
        if key in self._norm_aliases:
            return self._norm_aliases[key]

        # 前方一致 → 部分一致。1件に絞れたときだけ採用する。
        for match in (
            [k for nk, k in self._norm_index.items() if nk.startswith(key)],
            [k for nk, k in self._norm_index.items() if key in nk],
        ):
            if len(match) == 1:
                return match[0]

        # 候補提示: 正式名・別名の両方から、先頭数文字を含むものを拾う
        stem = key[:4]
        candidates = set()
        if stem:
            candidates |= {k for nk, k in self._norm_index.items() if stem in nk}
            candidates |= {v for nk, v in self._norm_aliases.items() if stem in nk}
        raise ComponentNotFound(name, sorted(candidates))

    # ── スタイル取得 ────────────────────────────────────────────
    def category_of(self, name):
        return self.index[self.resolve(name)]

    def _load_category(self, category):
        if category not in self._cat_cache:
            path = self.dir / f"{category}.json"
            if not path.exists():
                raise FileNotFoundError(f"カテゴリファイルがありません: {path}")
            self._cat_cache[category] = json.load(open(path, encoding="utf-8"))
        return self._cat_cache[category]

    def get(self, name):
        """正式名に解決したうえでコンポーネント定義（style/width/height…）を返す。"""
        canonical = self.resolve(name)
        return self._load_category(self.index[canonical])[canonical]

    def style(self, name):
        return self.get(name)["style"]

    def all_styles(self):
        """全コンポーネントの style -> 正式名。validate の照合用。"""
        out = {}
        for category in set(self.index.values()):
            try:
                for name, comp in self._load_category(category).items():
                    out[comp["style"]] = name
            except FileNotFoundError:
                continue
        return out

    def __len__(self):
        return len(self.index)


if __name__ == "__main__":
    import sys

    comps = Components()
    if len(sys.argv) > 1:
        for arg in sys.argv[1:]:
            try:
                canonical = comps.resolve(arg)
                print(f"{arg!r} -> {canonical!r}  [{comps.index[canonical]}]")
            except ComponentNotFound as e:
                print(e)
    else:
        print(f"{len(comps)} components, {len(comps.aliases)} aliases")
        for name in sorted(comps.index):
            print(f"  {comps.index[name]:12} {name}")
