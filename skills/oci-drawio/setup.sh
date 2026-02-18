#!/usr/bin/env bash
#
# setup.sh - OCI draw.io Skill initial setup
#
# Downloads Oracle Cloud Infrastructure (OCI) official SVG icons,
# converts them to draw.io format, and generates:
#   - icons/oci-shapes.xml       (draw.io custom shape library)
#   - components/oci_components.json (component dictionary for diagram generation)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICONS_DIR="${SCRIPT_DIR}/icons"
COMPONENTS_DIR="${SCRIPT_DIR}/components"
TMP_DIR="${SCRIPT_DIR}/.tmp"

# Oracle official download URLs
SVG_ZIP_URL="https://docs.oracle.com/en-us/iaas/Content/Resources/Assets/OCI_Icons_PNG_SVG.zip"

# ─── Color helpers ────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Dependency check ────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in curl unzip base64 python3; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing[*]}"
        error "Please install them and try again."
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
            warn "Download attempt $i failed. Retrying in ${retry_delay}s..."
            sleep "$retry_delay"
            retry_delay=$((retry_delay * 2))
        fi
    done
    return 1
}

# ─── Download & extract OCI icons ────────────────────────────
download_icons() {
    info "Downloading OCI icon set from Oracle..."
    info "URL: $SVG_ZIP_URL"

    mkdir -p "$TMP_DIR"

    if ! download_with_retry "$SVG_ZIP_URL" "${TMP_DIR}/oci_icons.zip"; then
        error "Failed to download OCI icon set."
        error "Please check your network connection and try again."
        error "You can also manually download from:"
        error "  $SVG_ZIP_URL"
        error "and extract it to: ${TMP_DIR}/oci_icons/"
        exit 1
    fi

    local filesize
    filesize=$(wc -c < "${TMP_DIR}/oci_icons.zip")
    if [[ "$filesize" -lt 1000 ]]; then
        error "Downloaded file is too small (${filesize} bytes). Download may have failed."
        exit 1
    fi

    info "Extracting icons..."
    unzip -qo "${TMP_DIR}/oci_icons.zip" -d "${TMP_DIR}/oci_icons"
}

# ─── Find SVG root directory ─────────────────────────────────
find_svg_root() {
    local search_dir="${TMP_DIR}/oci_icons"

    # Look for a directory named "SVG" (case-insensitive)
    local svg_dir
    svg_dir=$(find "$search_dir" -maxdepth 4 -type d -iname "SVG" 2>/dev/null | head -1)

    if [[ -n "$svg_dir" ]]; then
        echo "$svg_dir"
        return 0
    fi

    # Fallback: find directory containing most SVG files
    svg_dir=$(find "$search_dir" -name "*.svg" -print0 2>/dev/null \
        | xargs -0 -I{} dirname {} \
        | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')

    if [[ -n "$svg_dir" ]]; then
        # Return parent if this is a leaf category dir
        echo "$(dirname "$svg_dir")"
        return 0
    fi

    return 1
}

# ─── Generate outputs using Python ───────────────────────────
generate_outputs() {
    local svg_root="$1"

    info "Processing SVG files..."

    mkdir -p "$ICONS_DIR" "$COMPONENTS_DIR"

    python3 - "$svg_root" "$ICONS_DIR/oci-shapes.xml" "$COMPONENTS_DIR/oci_components.json" <<'PYTHON_SCRIPT'
import sys
import os
import json
import base64
import re
import urllib.parse
from pathlib import Path

svg_root = Path(sys.argv[1])
shapes_xml_path = sys.argv[2]
components_json_path = sys.argv[3]

# ── Category mapping: directory name -> normalized category ──
CATEGORY_MAP = {
    "compute": "compute",
    "networking": "networking",
    "network": "networking",
    "database": "database",
    "storage": "storage",
    "identitysecurity": "security",
    "identity security": "security",
    "identity": "security",
    "security": "security",
    "containers": "container",
    "container": "container",
    "developerservices": "developer",
    "developer services": "developer",
    "devops": "developer",
    "governance": "governance",
    "monitoring": "monitoring",
    "monitoringmanagement": "monitoring",
    "monitoring and management": "monitoring",
    "analyticsai": "ai",
    "analytics": "ai",
    "ai": "ai",
    "migration": "migration",
    "hybrid": "hybrid",
    "applications": "applications",
    "edge": "networking",
    "connectivity": "networking",
    "groups": "groups",
}

# ── Name normalization: filename -> human-readable name ──
# Map of known filename patterns to preferred display names
NAME_OVERRIDES = {
    "virtualcloudnetworkvcn": "VCN",
    "virtualcloudnetwork": "VCN",
    "vcn": "VCN",
    "internetgateway": "Internet Gateway",
    "natgateway": "NAT Gateway",
    "servicegateway": "Service Gateway",
    "dynamicroutinggatewaydrg": "DRG",
    "dynamicroutinggateway": "DRG",
    "drg": "DRG",
    "loadbalancerlb": "Load Balancer",
    "loadbalancer": "Load Balancer",
    "networkloadbalancernlb": "Network Load Balancer",
    "virtualmachine": "VM Instance",
    "virtualmachinevm": "VM (Desktop)",
    "baremetalcompute": "Bare Metal",
    "baremetal": "Bare Metal",
    "autoscaling": "Autoscaling",
    "functions": "Functions",
    "instancepools": "Instance Pools",
    "autonomousdatabase": "Autonomous Database",
    "mysqldatabasesystem": "MySQL HeatWave",
    "mysql": "MySQL HeatWave",
    "dbsystem": "DB System",
    "databasesystem": "DB System",
    "objectstorage": "Object Storage",
    "blockstorage": "Block Volume",
    "blockvolume": "Block Volume",
    "filestorage": "File Storage",
    "buckets": "Buckets",
    "webapplicationfirewallwaf": "WAF",
    "waf": "WAF",
    "firewall": "Network Firewall",
    "vault": "Vault",
    "keymanagement": "Key Management",
    "bastion": "Bastion",
    "iam": "IAM",
    "containerengine": "OKE",
    "containerengineforkubernetes": "OKE",
    "oke": "OKE",
    "containerinstances": "Container Instances",
    "containerinstance": "Container Instances",
    "containers": "Container Instances",
    "containerregistry": "OCIR",
    "ocir": "OCIR",
    "dns": "DNS",
    "cdn": "CDN",
    "emaildelivery": "Email Delivery",
    "streaming": "Streaming",
    "notifications": "Notifications",
    "queue": "Queue",
    "logging": "Logging",
    "monitoring": "Monitoring",
    "events": "Events",
    "audit": "Audit",
    "dataflow": "Data Flow",
    "datascience": "Data Science",
    "datasafe": "Data Safe",
    "exadata": "Exadata",
    "goldengate": "GoldenGate",
    "vnic": "VNIC",
    "routetable": "Route Table",
    "securitylist": "Security List",
    "securitylists": "Security List",
    "networksecuritygroupnsg": "NSG",
    "fastconnect": "FastConnect",
    "vpn": "VPN",
    "storagegateway": "Storage Gateway",
    "backuprestore": "Backup/Restore",
    "elasticperformance": "Elastic Performance",
    "certificates": "Certificates",
    "encryption": "Encryption",
    "flexvirtualmachinevm": "Flex VM",
    "burstablevirtualmachinevm": "Burstable VM",
    "virtualmachinegpu": "VM GPU",
    "persistentvolume": "Persistent Volume",
}

def normalize_category(dirname):
    """Map directory name to a normalized category."""
    key = dirname.lower().replace(" ", "").replace("-", "").replace("_", "")
    return CATEGORY_MAP.get(key, key)

def filename_to_key(filename):
    """Convert SVG filename to a lookup key."""
    name = Path(filename).stem
    # Remove common prefixes/suffixes
    name = re.sub(r'^oci[_-]?', '', name, flags=re.IGNORECASE)
    # Remove color variant suffixes
    name = re.sub(r'[_-]?(red|white|grey|gray|black|colored?)$', '', name, flags=re.IGNORECASE)
    return name.lower().replace(" ", "").replace("-", "").replace("_", "")

def filename_to_display(filename):
    """Convert SVG filename to a human-readable display name."""
    key = filename_to_key(filename)
    if key in NAME_OVERRIDES:
        return NAME_OVERRIDES[key]

    # Split PascalCase into words
    name = Path(filename).stem
    name = re.sub(r'([a-z])([A-Z])', r'\1 \2', name)
    name = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1 \2', name)
    # Remove OCI prefix
    name = re.sub(r'^OCI\s+', '', name)
    return name.strip()

def strip_svg_metadata(svg_text):
    """Remove metadata, XML declarations, and comments from SVG to reduce size by ~75%."""
    # Remove XML declaration
    svg_text = re.sub(r'<\?xml[^?]*\?>\s*', '', svg_text)
    # Remove metadata block (contains XMP data)
    svg_text = re.sub(r'<metadata>.*?</metadata>', '', svg_text, flags=re.DOTALL)
    # Remove XML comments
    svg_text = re.sub(r'<!--.*?-->', '', svg_text, flags=re.DOTALL)
    # Remove unnecessary whitespace between tags
    svg_text = re.sub(r'>\s+<', '><', svg_text)
    return svg_text.strip()

def svg_to_base64_data_uri(svg_path):
    """Read an SVG file, strip metadata, and return a base64 data URI."""
    with open(svg_path, 'rb') as f:
        raw = f.read()
    # Decode with fallback for non-UTF-8 SVGs
    for enc in ('utf-8', 'latin-1'):
        try:
            svg_text = raw.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    else:
        # Last resort: decode ignoring errors
        svg_text = raw.decode('utf-8', errors='ignore')
    svg_text = strip_svg_metadata(svg_text)
    b64 = base64.b64encode(svg_text.encode('utf-8')).decode('ascii')
    # Use "data:image/svg+xml," (without ";base64") for draw.io compatibility.
    # draw.io's style parser uses ";" as delimiter, so ";base64" breaks the image= value.
    # draw.io treats the content after "," as base64 regardless of the explicit marker.
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

# Find all SVG files, preferring Red/colored variants
svg_files = {}  # key -> (path, category, display_name)

# Walk the directory tree looking for SVG files
for dirpath, dirnames, filenames in os.walk(svg_root):
    rel = Path(dirpath).relative_to(svg_root)
    parts = list(rel.parts)

    for fname in sorted(filenames):
        if not fname.lower().endswith('.svg'):
            continue
        # Skip macOS resource fork files
        if fname.startswith('._'):
            continue

        full_path = Path(dirpath) / fname
        key = filename_to_key(fname)

        if not key:
            continue

        # Determine category from directory structure
        # Typical structures:
        #   SVG/Category/icon.svg
        #   SVG/Color/Category/icon.svg
        #   Category/icon.svg
        category = "general"
        for p in parts:
            p_lower = p.lower().replace(" ", "").replace("-", "").replace("_", "")
            if p_lower in CATEGORY_MAP:
                category = CATEGORY_MAP[p_lower]
                break
            # Skip color variant directories
            if p_lower in ("red", "white", "grey", "gray", "black", "color", "colored"):
                continue
            # If not a known color or category, use it as category
            if p_lower not in ("svg", "png", "icons", "oci_icons", "oci", "ociicons"):
                category = normalize_category(p)

        display_name = filename_to_display(fname)

        # Prefer Red variant (Oracle brand color), but accept any
        if key not in svg_files:
            svg_files[key] = (str(full_path), category, display_name)
        else:
            # Prefer Red/colored variants
            current_path = svg_files[key][0]
            path_lower = str(full_path).lower()
            if '/red/' in path_lower and '/red/' not in current_path.lower():
                svg_files[key] = (str(full_path), category, display_name)

print(f"Found {len(svg_files)} unique SVG icons", file=sys.stderr)

if not svg_files:
    print("ERROR: No SVG files found!", file=sys.stderr)
    sys.exit(1)

# ── Generate oci-shapes.xml (mxlibrary) ──
library_entries = []
for key in sorted(svg_files.keys()):
    path, category, display_name = svg_files[key]
    data_uri = svg_to_base64_data_uri(path)
    entry = {
        "data": data_uri,
        "w": 60,
        "h": 60,
        "title": display_name,
        "aspect": "fixed",
    }
    library_entries.append(entry)

shapes_xml = f"<mxlibrary>{json.dumps(library_entries, separators=(',', ':'))}</mxlibrary>\n"

with open(shapes_xml_path, 'w') as f:
    f.write(shapes_xml)

print(f"Generated: {shapes_xml_path} ({len(library_entries)} shapes)", file=sys.stderr)

# ── Generate oci_components.json ──
components = {}
for key in sorted(svg_files.keys()):
    path, category, display_name = svg_files[key]
    data_uri = svg_to_base64_data_uri(path)
    style = build_style(data_uri)
    components[display_name] = {
        "style": style,
        "width": 60,
        "height": 60,
        "category": category,
        "description": display_name,
        "svg_file": os.path.basename(path),
    }

with open(components_json_path, 'w') as f:
    json.dump(components, f, indent=2, ensure_ascii=False)

print(f"Generated: {components_json_path} ({len(components)} components)", file=sys.stderr)
PYTHON_SCRIPT
}

# ─── Cleanup ──────────────────────────────────────────────────
cleanup() {
    if [[ -d "$TMP_DIR" ]]; then
        info "Cleaning up temporary files..."
        rm -rf "$TMP_DIR"
    fi
}

# ─── Main ─────────────────────────────────────────────────────
main() {
    info "========================================="
    info "  OCI draw.io Skill - Setup"
    info "========================================="
    echo

    check_deps
    download_icons

    local svg_root
    svg_root=$(find_svg_root)

    if [[ -z "$svg_root" ]]; then
        error "Could not find SVG directory in the downloaded archive."
        error "Please check the archive contents in: ${TMP_DIR}/oci_icons/"
        exit 1
    fi

    info "Found SVG root: $svg_root"

    # Count SVG files
    local svg_count
    svg_count=$(find "$svg_root" -name "*.svg" 2>/dev/null | wc -l)
    info "Found $svg_count SVG files"

    if [[ "$svg_count" -eq 0 ]]; then
        error "No SVG files found in: $svg_root"
        exit 1
    fi

    generate_outputs "$svg_root"

    cleanup

    echo
    info "========================================="
    info "  Setup complete!"
    info "========================================="
    info ""
    info "Generated files:"
    info "  icons/oci-shapes.xml           - draw.io custom shape library"
    info "  components/oci_components.json - component dictionary"
    info ""
    info "To use in draw.io:"
    info "  File -> Open Library -> select icons/oci-shapes.xml"
    info ""
    info "For programmatic diagram generation, see SKILL.md"
}

trap cleanup EXIT
main "$@"
