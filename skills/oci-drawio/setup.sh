#!/usr/bin/env bash
#
# setup.sh - OCI アイコンの取得と再生成
#
# 生成済みのデータはリポジトリに同梱されているため、通常このスクリプトを実行する
# 必要はない。Oracle がアイコンセットを更新したときに再取得するために使う。
#
# 生成物:
#   icons/oci-shapes.xml          draw.io カスタムシェイプライブラリ（GUI用）
#   components/index.json         コンポーネント名 -> カテゴリ
#   components/{カテゴリ}.json     style を含む定義
#
# 使い方:
#   bash setup.sh                      Oracle からダウンロードして生成
#   bash setup.sh --from-zip icons.zip 手元の zip から生成（ネットワーク不要）
#   bash setup.sh --help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICONS_DIR="${SCRIPT_DIR}/icons"
COMPONENTS_DIR="${SCRIPT_DIR}/components"
TMP_DIR="${SCRIPT_DIR}/.tmp"
STAGE_DIR="${TMP_DIR}/stage"

# Oracle 公式のダウンロード URL
# 変更された場合は --from-zip で手元の zip を渡せる
SVG_ZIP_URL="https://docs.oracle.com/en-us/iaas/Content/Resources/Assets/OCI_Icons_PNG_SVG.zip"

# 生成結果の健全性チェック: これを下回ったら異常とみなし、既存データを差し替えない
MIN_COMPONENTS=100

FROM_ZIP=""
KEEP_TMP=0

# ─── Color helpers ────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# ─── Dependency check ────────────────────────────────────────
check_deps() {
    local missing=()
    local required=(unzip base64 python3)
    [[ -z "$FROM_ZIP" ]] && required+=(curl)

    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "必要なコマンドがありません: ${missing[*]}"
        exit 1
    fi
}

# ─── Download with retry ─────────────────────────────────────
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry_delay=2

    for ((i = 1; i <= max_retries; i++)); do
        if curl -fSL --connect-timeout 30 --max-time 300 -o "$output" "$url" 2>/dev/null; then
            return 0
        fi
        if [[ $i -lt $max_retries ]]; then
            warn "ダウンロード失敗 ($i 回目)。${retry_delay}秒後に再試行します..."
            sleep "$retry_delay"
            retry_delay=$((retry_delay * 2))
        fi
    done
    return 1
}

# ─── Obtain & extract OCI icons ──────────────────────────────
obtain_icons() {
    mkdir -p "$TMP_DIR"
    local zip_path="${TMP_DIR}/oci_icons.zip"

    if [[ -n "$FROM_ZIP" ]]; then
        if [[ ! -f "$FROM_ZIP" ]]; then
            error "zip が見つかりません: $FROM_ZIP"
            exit 1
        fi
        info "手元の zip を使用します: $FROM_ZIP"
        cp "$FROM_ZIP" "$zip_path"
    else
        info "Oracle から OCI アイコンセットをダウンロードします..."
        info "URL: $SVG_ZIP_URL"
        if ! download_with_retry "$SVG_ZIP_URL" "$zip_path"; then
            error "ダウンロードに失敗しました。"
            error "URL が変更された可能性があります。以下を確認してください:"
            error "  https://docs.oracle.com/en-us/iaas/Content/General/Reference/graphicsfordiagrams.htm"
            error "手元に zip がある場合は次のように実行できます:"
            error "  bash setup.sh --from-zip /path/to/OCI_Icons_PNG_SVG.zip"
            error "（既存の components/ と icons/ は変更していません）"
            exit 1
        fi
    fi

    local filesize
    filesize=$(wc -c < "$zip_path")
    if [[ "$filesize" -lt 1000 ]]; then
        error "取得したファイルが小さすぎます (${filesize} bytes)。"
        exit 1
    fi

    info "展開しています..."
    unzip -qo "$zip_path" -d "${TMP_DIR}/oci_icons"
}

# ─── Find SVG root directory ─────────────────────────────────
find_svg_root() {
    local search_dir="${TMP_DIR}/oci_icons"

    local svg_dir
    svg_dir=$(find "$search_dir" -maxdepth 4 -type d -iname "SVG" 2>/dev/null | head -1)

    if [[ -n "$svg_dir" ]]; then
        echo "$svg_dir"
        return 0
    fi

    # フォールバック: SVG を最も多く含むディレクトリの親
    svg_dir=$(find "$search_dir" -name "*.svg" -print0 2>/dev/null \
        | xargs -0 -I{} dirname {} \
        | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')

    if [[ -n "$svg_dir" ]]; then
        echo "$(dirname "$svg_dir")"
        return 0
    fi

    return 1
}

# ─── Generate outputs using Python ───────────────────────────
# 生成はすべてステージング領域に対して行い、健全性チェックを通ったときだけ
# 本来の場所へ差し替える（途中で失敗しても既存データを壊さない）。
generate_outputs() {
    local svg_root="$1"

    info "SVG を処理しています..."
    rm -rf "$STAGE_DIR"
    mkdir -p "$STAGE_DIR/icons" "$STAGE_DIR/components"

    python3 - "$svg_root" "$STAGE_DIR" "$COMPONENTS_DIR/name_overrides.json" \
        "$MIN_COMPONENTS" <<'PYTHON_SCRIPT'
import sys
import os
import json
import base64
import re
from collections import defaultdict
from pathlib import Path

svg_root = Path(sys.argv[1])
stage_dir = Path(sys.argv[2])
name_overrides_path = Path(sys.argv[3])
min_components = int(sys.argv[4])

shapes_xml_path = stage_dir / "icons" / "oci-shapes.xml"
components_dir = stage_dir / "components"

# ── Category mapping: directory name -> normalized category ──
CATEGORY_MAP = {
    "compute": "compute",
    "networking": "networking",
    "network": "networking",
    "database": "database",
    "storage": "storage",
    "identitysecurity": "security",
    "identity security": "security",
    "identityandsecurity": "security",
    "identity&security": "security",
    "identity": "security",
    "security": "security",
    "containers": "container",
    "container": "container",
    "developerservices": "developer",
    "developer services": "developer",
    "developer": "developer",
    "devops": "developer",
    "governance": "governance",
    "monitoring": "monitoring",
    "monitoringmanagement": "monitoring",
    "monitoring and management": "monitoring",
    "observabilityandmanagement": "monitoring",
    "observability&management": "monitoring",
    "observabilitymanagement": "monitoring",
    "analyticsai": "ai",
    "analytics&ai": "ai",
    "analyticsandai": "ai",
    "analytics": "ai",
    "ai": "ai",
    "migration": "migration",
    "hybrid": "hybrid",
    "applications": "applications",
    "edge": "networking",
    "connectivity": "networking",
    "groups": "groups",
    "marketplace": "applications",
    "other": "general",
    "ociuploadedtoomm": "general",
}

# カテゴリ名をファイル名として使えるものへ正規化する。
# ここに無い未知のカテゴリは general にまとめ、警告を出す。
CAT_NORMALIZE = {
    "analytics&ai": "ai", "analyticsai": "ai", "analyticsandai": "ai",
    "identity&security": "security", "identitysecurity": "security",
    "identityandsecurity": "security",
    "observabilityandmanagement": "monitoring",
    "observability&management": "monitoring",
    "observabilitymanagement": "monitoring", "monitoringmanagement": "monitoring",
    "marketplace": "applications",
    "ociuploadedtoomm": "general", "other": "general",
    "containers": "container",
}
KNOWN_CATEGORIES = {
    "networking", "compute", "database", "storage", "security", "container",
    "developer", "governance", "monitoring", "ai", "migration", "hybrid",
    "applications", "general", "groups",
}

# ── Name normalization: filename -> human-readable name ──
# 表示名の単一情報源は components/name_overrides.json（filename_key -> 表示名）。
# ここに無いものだけ PascalCase 分割にフォールバックする。
if name_overrides_path.exists():
    with open(name_overrides_path, encoding="utf-8") as f:
        NAME_OVERRIDES = {k: v for k, v in json.load(f).items() if not k.startswith("_")}
    print(f"Loaded {len(NAME_OVERRIDES)} name overrides from {name_overrides_path}",
          file=sys.stderr)
else:
    NAME_OVERRIDES = {}
    print(f"WARNING: {name_overrides_path} not found; falling back to auto-generated names",
          file=sys.stderr)

def normalize_category(dirname):
    """Map directory name to a normalized category."""
    key = dirname.lower().replace(" ", "").replace("-", "").replace("_", "")
    return CATEGORY_MAP.get(key, key)

def filename_to_key(filename):
    """Convert SVG filename to a lookup key."""
    name = Path(filename).stem
    name = re.sub(r'^oci[_-]?', '', name, flags=re.IGNORECASE)
    name = re.sub(r'[_-]?(red|white|grey|gray|black|colored?)$', '', name, flags=re.IGNORECASE)
    return name.lower().replace(" ", "").replace("-", "").replace("_", "")

def filename_to_display(filename):
    """Convert SVG filename to a human-readable display name."""
    key = filename_to_key(filename)
    if key in NAME_OVERRIDES:
        return NAME_OVERRIDES[key]

    name = Path(filename).stem
    name = re.sub(r'([a-z])([A-Z])', r'\1 \2', name)
    name = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1 \2', name)
    name = re.sub(r'^OCI\s+', '', name)
    return name.strip()

def strip_svg_metadata(svg_text):
    """Remove metadata, XML declarations, and comments from SVG to reduce size."""
    svg_text = re.sub(r'<\?xml[^?]*\?>\s*', '', svg_text)
    svg_text = re.sub(r'<metadata>.*?</metadata>', '', svg_text, flags=re.DOTALL)
    svg_text = re.sub(r'<!--.*?-->', '', svg_text, flags=re.DOTALL)
    svg_text = re.sub(r'<title>.*?</title>', '', svg_text, flags=re.DOTALL)
    svg_text = re.sub(r'<desc>.*?</desc>', '', svg_text, flags=re.DOTALL)
    svg_text = re.sub(r'>\s+<', '><', svg_text)
    return svg_text.strip()

def svg_to_base64_data_uri(svg_path):
    """Read an SVG file, strip metadata, and return a base64 data URI."""
    with open(svg_path, 'rb') as f:
        raw = f.read()
    for enc in ('utf-8', 'latin-1'):
        try:
            svg_text = raw.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    else:
        svg_text = raw.decode('utf-8', errors='ignore')
    svg_text = strip_svg_metadata(svg_text)
    b64 = base64.b64encode(svg_text.encode('utf-8')).decode('ascii')
    # draw.io のスタイルは ";" 区切りのため ";base64" は使えない。
    # "data:image/svg+xml," の後ろに base64 を置くと draw.io が解釈できる。
    return f"data:image/svg+xml,{b64}"

def build_style(data_uri):
    """Build a draw.io style string for an image shape."""
    return (
        f"shape=image;verticalLabelPosition=bottom;labelBackgroundColor=none;"
        f"labelPosition=center;verticalAlign=top;aspect=fixed;"
        f"imageAspect=0;image={data_uri};"
    )

# ── Scan SVG files ──
print(f"Scanning SVGs in: {svg_root}", file=sys.stderr)

svg_files = {}  # key -> (path, category, display_name)

for dirpath, dirnames, filenames in os.walk(svg_root):
    rel = Path(dirpath).relative_to(svg_root)
    parts = list(rel.parts)

    for fname in sorted(filenames):
        if not fname.lower().endswith('.svg'):
            continue
        if fname.startswith('._'):   # macOS のリソースフォーク
            continue

        full_path = Path(dirpath) / fname
        key = filename_to_key(fname)
        if not key:
            continue

        # ディレクトリ構成からカテゴリを決める
        #   SVG/Category/icon.svg / SVG/Color/Category/icon.svg / Category/icon.svg
        category = "general"
        for p in parts:
            p_lower = p.lower().replace(" ", "").replace("-", "").replace("_", "")
            if p_lower in CATEGORY_MAP:
                category = CATEGORY_MAP[p_lower]
                break
            if p_lower in ("red", "white", "grey", "gray", "black", "color", "colored"):
                continue
            if p_lower not in ("svg", "png", "icons", "oci_icons", "oci", "ociicons"):
                category = normalize_category(p)

        display_name = filename_to_display(fname)

        if key not in svg_files:
            svg_files[key] = (str(full_path), category, display_name)
        else:
            # Oracle ブランドカラーの Red 版を優先する
            current_path = svg_files[key][0]
            path_lower = str(full_path).lower()
            if '/red/' in path_lower and '/red/' not in current_path.lower():
                svg_files[key] = (str(full_path), category, display_name)

print(f"Found {len(svg_files)} unique SVG icons", file=sys.stderr)

if len(svg_files) < min_components:
    print(f"ERROR: 検出できたアイコンが {len(svg_files)} 件しかありません "
          f"（最低 {min_components} 件必要）。アーカイブの構造が変わった可能性があります。",
          file=sys.stderr)
    sys.exit(1)

# ── データ URI は 1 アイコンにつき 1 回だけ生成する ──
data_uris = {key: svg_to_base64_data_uri(svg_files[key][0]) for key in svg_files}

# ── Generate oci-shapes.xml (mxlibrary) ──
library_entries = [
    {
        "data": data_uris[key],
        "w": 60,
        "h": 60,
        "title": svg_files[key][2],
        "aspect": "fixed",
    }
    for key in sorted(svg_files)
]
shapes_xml = f"<mxlibrary>{json.dumps(library_entries, separators=(',', ':'))}</mxlibrary>\n"
shapes_xml_path.write_text(shapes_xml, encoding="utf-8")
print(f"Generated: {shapes_xml_path} ({len(library_entries)} shapes)", file=sys.stderr)

# ── Build component dictionary ──
components = {}
for key in sorted(svg_files):
    path, category, display_name = svg_files[key]
    components[display_name] = {
        "style": build_style(data_uris[key]),
        "width": 60,
        "height": 60,
        "category": category,
        "description": display_name,
        "svg_file": os.path.basename(path),
    }

# ── index.json + カテゴリ別ファイル ──
# 全部入りの辞書は各カテゴリファイルと完全に重複するため生成しない。
index = {}
by_category = defaultdict(dict)
unknown_categories = set()
for name, comp in components.items():
    cat = CAT_NORMALIZE.get(comp["category"], comp["category"])
    if cat not in KNOWN_CATEGORIES:
        unknown_categories.add(cat)
        cat = "general"
    index[name] = cat
    by_category[cat][name] = comp

if unknown_categories:
    print(f"WARNING: 未知のカテゴリを general にまとめました: "
          f"{sorted(unknown_categories)}", file=sys.stderr)

with open(components_dir / "index.json", 'w', encoding="utf-8") as f:
    json.dump(dict(sorted(index.items())), f, indent=2, ensure_ascii=False)
print(f"Generated: index.json ({len(index)} entries)", file=sys.stderr)

for cat, cat_components in sorted(by_category.items()):
    with open(components_dir / f"{cat}.json", 'w', encoding="utf-8") as f:
        json.dump(cat_components, f, indent=2, ensure_ascii=False)
    print(f"Generated: {cat}.json ({len(cat_components)} components)", file=sys.stderr)
PYTHON_SCRIPT
}

# ─── ステージングの検証と差し替え ────────────────────────────
promote_outputs() {
    local count
    count=$(python3 -c "
import json
print(len(json.load(open('${STAGE_DIR}/components/index.json'))))
" 2>/dev/null || echo 0)

    if [[ "$count" -lt "$MIN_COMPONENTS" ]]; then
        error "生成結果が不十分です (${count} 件)。既存データは変更していません。"
        exit 1
    fi
    if [[ ! -s "${STAGE_DIR}/icons/oci-shapes.xml" ]]; then
        error "oci-shapes.xml が生成されていません。既存データは変更していません。"
        exit 1
    fi

    info "検証に成功しました (${count} コンポーネント)。差し替えます..."

    mkdir -p "$ICONS_DIR" "$COMPONENTS_DIR"
    # 手で管理しているファイル（name_overrides.json / aliases.json）は残す
    find "$COMPONENTS_DIR" -maxdepth 1 -name '*.json' \
        ! -name 'name_overrides.json' ! -name 'aliases.json' -delete
    cp "${STAGE_DIR}/components/"*.json "$COMPONENTS_DIR/"
    cp "${STAGE_DIR}/icons/oci-shapes.xml" "$ICONS_DIR/oci-shapes.xml"

    if [[ -f "${SCRIPT_DIR}/scripts/gen_component_list.py" ]]; then
        mkdir -p "${SCRIPT_DIR}/reference"
        (cd "$SCRIPT_DIR" && python3 scripts/gen_component_list.py \
            > reference/component-list.md)
        info "reference/component-list.md を更新しました"
    fi
}

# ─── Cleanup ──────────────────────────────────────────────────
cleanup() {
    if [[ -d "$TMP_DIR" && "$KEEP_TMP" -eq 0 ]]; then
        rm -rf "$TMP_DIR"
    fi
}

# ─── Main ─────────────────────────────────────────────────────
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from-zip)
                [[ $# -lt 2 ]] && { error "--from-zip にはパスが必要です"; exit 1; }
                FROM_ZIP="$2"; shift 2 ;;
            --keep-tmp)
                KEEP_TMP=1; shift ;;
            --help|-h)
                show_help; exit 0 ;;
            *)
                error "不明なオプション: $1"; echo; show_help; exit 1 ;;
        esac
    done

    info "========================================="
    info "  OCI draw.io Skill - アイコン再生成"
    info "========================================="
    echo

    check_deps
    obtain_icons

    local svg_root
    svg_root=$(find_svg_root) || true

    if [[ -z "$svg_root" ]]; then
        error "アーカイブ内に SVG ディレクトリが見つかりませんでした。"
        error "中身を確認してください: ${TMP_DIR}/oci_icons/"
        error "（既存の components/ と icons/ は変更していません）"
        exit 1
    fi

    info "SVG ルート: $svg_root"

    local svg_count
    svg_count=$(find "$svg_root" -name "*.svg" 2>/dev/null | wc -l)
    info "SVG ファイル: $svg_count 件"

    generate_outputs "$svg_root"
    promote_outputs
    cleanup

    echo
    info "========================================="
    info "  完了"
    info "========================================="
    info ""
    info "生成物:"
    info "  icons/oci-shapes.xml       draw.io カスタムシェイプライブラリ"
    info "  components/index.json      コンポーネント名 -> カテゴリ"
    info "  components/{カテゴリ}.json  style を含む定義"
    info ""
    info "draw.io の GUI で使う場合:"
    info "  File -> Open Library -> icons/oci-shapes.xml を選択"
    info ""
    info "図の生成方法は SKILL.md を参照してください。"
}

trap cleanup EXIT
main "$@"
