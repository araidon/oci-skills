#!/usr/bin/env bash
#
# install.sh - Install OCI Skills for Claude Code or Codex
#
# Usage:
#   ./install.sh <skill-name>                       # Claude Code (default)
#   ./install.sh <skill-name> --tool codex          # Codex global (~/.codex/skills/)
#   ./install.sh <skill-name> --tool codex-local    # Codex project (.codex/skills/)
#   ./install.sh <skill-name> --tool claude-local   # Claude Code project (.claude/skills/)
#   ./install.sh --uninstall <skill-name>           # Uninstall
#   ./install.sh --list                             # List available skills
#   ./install.sh --all                              # Install all skills
#   ./install.sh --help                             # Show help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/skills"

# --yes / -y で上書き確認を省略する
ASSUME_YES=0

# ─── Color helpers ────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── List available skills ────────────────────────────────────
list_skills() {
    echo -e "${BOLD}Available Skills:${NC}"
    echo

    local found=0
    for skill_dir in "${SKILLS_DIR}"/*/; do
        [[ -d "$skill_dir" ]] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")

        # Try to read description from SKILL.md frontmatter
        local description=""
        if [[ -f "${skill_dir}/SKILL.md" ]]; then
            description=$(sed -n '/^---$/,/^---$/{ /^description:/{ s/^description: *//; p; } }' "${skill_dir}/SKILL.md" 2>/dev/null || true)
        fi

        if [[ -n "$description" ]]; then
            echo -e "  ${CYAN}${skill_name}${NC}"
            echo -e "    ${description}"
        else
            echo -e "  ${CYAN}${skill_name}${NC}"
        fi
        echo
        found=$((found + 1))
    done

    if [[ $found -eq 0 ]]; then
        echo "  (no skills found)"
    fi
}

VALID_TOOLS="claude claude-local codex codex-local codex-repo"

# ─── Validate the --tool value ────────────────────────────────
# get_install_dir はコマンド置換の中で呼ばれるため、そこで error/exit しても
# メッセージが変数に吸われ、set -e で無言終了してしまう。検証はここで行う。
validate_tool() {
    local tool="$1"
    for valid in $VALID_TOOLS; do
        [[ "$tool" == "$valid" ]] && return 0
    done
    error "Unknown tool: ${tool}"
    error "Valid options: ${VALID_TOOLS// /, }"
    return 1
}

# ─── Determine install destination ────────────────────────────
get_install_dir() {
    local skill_name="$1"
    local tool="${2:-claude}"

    case "$tool" in
        claude)
            echo "${HOME}/.claude/skills/${skill_name}"
            ;;
        claude-local)
            # プロジェクトローカルの .claude/skills/
            local git_root
            git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
            echo "${git_root}/.claude/skills/${skill_name}"
            ;;
        codex)
            echo "${HOME}/.codex/skills/${skill_name}"
            ;;
        codex-local)
            # Install to project-local .codex/skills/
            local git_root
            git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
            echo "${git_root}/.codex/skills/${skill_name}"
            ;;
        codex-repo)
            # Install to .agents/skills/ (Codex repo scan)
            local git_root
            git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
            echo "${git_root}/.agents/skills/${skill_name}"
            ;;
        *)
            # ここには validate_tool を通っていれば到達しない
            echo "__INVALID_TOOL__"
            ;;
    esac
}

# ─── Install a single skill ──────────────────────────────────
install_skill() {
    local skill_name="$1"
    local tool="$2"

    local source_dir="${SKILLS_DIR}/${skill_name}"

    if [[ ! -d "$source_dir" ]]; then
        error "Skill not found: ${skill_name}"
        error "Run './install.sh --list' to see available skills."
        exit 1
    fi

    local dest_dir
    dest_dir=$(get_install_dir "$skill_name" "$tool")

    if [[ -d "$dest_dir" ]]; then
        if [[ $ASSUME_YES -eq 0 ]]; then
            warn "既にインストールされています: ${dest_dir}"
            warn "上書きすると、そこでの変更（setup.sh で取得したアイコン等）は失われます。"
            read -r -p "上書きしますか? [y/N] " reply </dev/tty 2>/dev/null || reply=""
            if [[ ! "$reply" =~ ^[Yy]$ ]]; then
                info "スキップしました: ${skill_name}"
                return 0
            fi
        fi
        rm -rf "$dest_dir"
    fi

    info "Installing ${BOLD}${skill_name}${NC}${GREEN} to: ${dest_dir}${NC}"

    mkdir -p "$(dirname "$dest_dir")"
    cp -r "$source_dir" "$dest_dir"
    # Clean up temp/cache files
    rm -rf "${dest_dir}/.tmp" "${dest_dir}/__pycache__"

    # setup.sh は同梱データの再生成用。インストール直後に実行する必要はない。
    if [[ -f "${dest_dir}/setup.sh" ]]; then
        echo
        info "アイコンは同梱済みなので、そのまま使えます。"
        info "Oracle のアイコンを取り直したい場合のみ:"
        echo -e "  ${CYAN}cd ${dest_dir} && bash setup.sh${NC}"
    fi

    echo
    info "Installed ${BOLD}${skill_name}${NC}${GREEN} successfully!${NC}"
}

# ─── Uninstall a skill ───────────────────────────────────────
uninstall_skill() {
    local skill_name="$1"
    local tool="$2"

    local dest_dir
    dest_dir=$(get_install_dir "$skill_name" "$tool")

    if [[ ! -d "$dest_dir" ]]; then
        warn "インストールされていません: ${dest_dir}"
        return 0
    fi

    if [[ $ASSUME_YES -eq 0 ]]; then
        warn "削除します: ${dest_dir}"
        read -r -p "本当に削除しますか? [y/N] " reply </dev/tty 2>/dev/null || reply=""
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            info "中止しました。"
            return 0
        fi
    fi

    rm -rf "$dest_dir"
    info "Uninstalled ${BOLD}${skill_name}${NC}${GREEN} (${dest_dir})${NC}"
}

# ─── Install all skills ──────────────────────────────────────
install_all() {
    local tool="$1"
    local count=0

    for skill_dir in "${SKILLS_DIR}"/*/; do
        [[ -d "$skill_dir" ]] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")
        install_skill "$skill_name" "$tool"
        count=$((count + 1))
        echo
    done

    if [[ $count -eq 0 ]]; then
        warn "No skills found to install."
    else
        info "Installed ${count} skill(s)."
    fi
}

# ─── Help ─────────────────────────────────────────────────────
show_help() {
    echo -e "${BOLD}oci-skills installer${NC}"
    echo
    echo -e "${BOLD}Usage:${NC}"
    echo "  ./install.sh <skill-name>                       Install for Claude Code (default)"
    echo "  ./install.sh <skill-name> --tool <target>       Install for a specific tool"
    echo "  ./install.sh --uninstall <skill-name>           Uninstall a skill"
    echo "  ./install.sh --list                             List available skills"
    echo "  ./install.sh --all                              Install all skills"
    echo "  ./install.sh --all --tool <target>              Install all skills for a specific tool"
    echo "  ./install.sh --help                             Show this help"
    echo
    echo -e "${BOLD}Targets (--tool):${NC}"
    echo "  claude        ~/.claude/skills/<name>/         Claude Code (default)"
    echo "  claude-local  .claude/skills/<name>/           Claude Code project-local"
    echo "  codex         ~/.codex/skills/<name>/          Codex global"
    echo "  codex-local   .codex/skills/<name>/            Codex project-local"
    echo "  codex-repo    .agents/skills/<name>/           Codex repository scan"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./install.sh oci-drawio                        Install oci-drawio for Claude Code"
    echo "  ./install.sh oci-drawio --tool codex           Install oci-drawio for Codex (global)"
    echo "  ./install.sh oci-drawio --tool codex-local     Install oci-drawio in current project"
    echo "  ./install.sh --all --tool codex                Install all skills for Codex"
    echo "  ./install.sh oci-drawio --tool claude-local    Install into the current project"
    echo "  ./install.sh --uninstall oci-drawio            Remove it again"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo "  -y, --yes     Do not ask before overwriting or deleting"
    echo
    echo -e "${BOLD}After Installation:${NC}"
    echo "  oci-drawio はアイコンを同梱しているため、そのまま使えます。"
    echo "  setup.sh は Oracle のアイコンを取り直したいときだけ実行してください。"
}

# ─── Main ─────────────────────────────────────────────────────
main() {
    local skill_name=""
    local tool="claude"
    local action=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list|-l)
                action="list"
                shift
                ;;
            --all|-a)
                action="all"
                shift
                ;;
            --help|-h)
                action="help"
                shift
                ;;
            --uninstall|-u)
                action="uninstall"
                shift
                ;;
            --yes|-y)
                ASSUME_YES=1
                shift
                ;;
            --tool|-t)
                if [[ $# -lt 2 ]]; then
                    error "--tool requires an argument"
                    exit 1
                fi
                tool="$2"
                shift 2
                ;;
            -*)
                error "Unknown option: $1"
                echo "Run './install.sh --help' for usage."
                exit 1
                ;;
            *)
                skill_name="$1"
                shift
                ;;
        esac
    done

    # --tool の検証はここで行う（コマンド置換の外なので、エラーが表示される）
    if [[ "$action" != "list" && "$action" != "help" ]]; then
        validate_tool "$tool" || exit 1
    fi

    case "$action" in
        list)
            list_skills
            ;;
        uninstall)
            if [[ -z "$skill_name" ]]; then
                error "スキル名が指定されていません。"
                echo
                show_help
                exit 1
            fi
            uninstall_skill "$skill_name" "$tool"
            ;;
        all)
            install_all "$tool"
            ;;
        help)
            show_help
            ;;
        *)
            if [[ -z "$skill_name" ]]; then
                error "No skill name specified."
                echo
                show_help
                exit 1
            fi
            install_skill "$skill_name" "$tool"
            ;;
    esac
}

main "$@"
