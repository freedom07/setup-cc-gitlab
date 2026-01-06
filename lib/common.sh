#!/usr/bin/env bash
#
# Common utilities for Claude Code CI Setup
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}→${NC}"
INFO="${BLUE}ℹ${NC}"
WARN="${YELLOW}⚠${NC}"

#######################################
# Print formatted log message
# Arguments:
#   $1 - Log level (info, success, warn, error, debug)
#   $2 - Message
#######################################
log() {
    local level="$1"
    local message="$2"

    case $level in
        info)
            echo -e "  ${INFO} ${message}"
            ;;
        success)
            echo -e "  ${CHECK} ${message}"
            ;;
        warn)
            echo -e "  ${WARN} ${YELLOW}${message}${NC}"
            ;;
        error)
            echo -e "  ${CROSS} ${RED}${message}${NC}" >&2
            ;;
        debug)
            if [[ "${VERBOSE:-false}" == "true" ]]; then
                echo -e "  ${DIM}[DEBUG] ${message}${NC}"
            fi
            ;;
        *)
            echo -e "  ${message}"
            ;;
    esac
}

#######################################
# Print step header
# Arguments:
#   $1 - Step number
#   $2 - Total steps
#   $3 - Step description
#######################################
step() {
    local num="$1"
    local total="$2"
    local desc="$3"
    echo ""
    echo -e "${BOLD}[${num}/${total}] ${desc}${NC}"
}

#######################################
# Print script header
#######################################
print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}🚀 Claude Code CI Setup${NC}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

#######################################
# Print completion message
#######################################
print_completion() {
    echo ""
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Setup complete!${NC}"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo -e "  1. Review and commit the changes:"
    echo -e "     ${DIM}git add .gitlab-ci.yml && git commit -m \"Add Claude Code CI\"${NC}"
    echo ""
    echo -e "  2. Push to trigger the pipeline:"
    echo -e "     ${DIM}git push${NC}"
    echo ""
    echo -e "  3. Mention ${CYAN}@claude${NC} in an MR or issue to interact with Claude"
    echo ""
    echo -e "${DIM}Documentation: https://code.claude.com/docs/gitlab-ci-cd${NC}"
    echo ""
}

#######################################
# Check if yq is installed
# Returns:
#   0 if yq is available, 1 otherwise
#######################################
check_yq() {
    if command -v yq &> /dev/null; then
        log debug "yq found: $(which yq)"
        return 0
    else
        return 1
    fi
}

#######################################
# Install yq automatically
# Returns:
#   0 if installation successful, 1 otherwise
#######################################
install_yq() {
    echo -e "  ${INFO} yq not found. Installing..."
    echo ""

    local install_dir="${HOME}/.local/bin"
    local yq_binary=""

    # Detect OS and architecture
    local os=""
    local arch=""

    case "$OSTYPE" in
        darwin*)
            os="darwin"
            ;;
        linux*)
            os="linux"
            ;;
        *)
            echo -e "  ${CROSS} Unsupported OS: $OSTYPE"
            return 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)
            arch="amd64"
            ;;
        arm64|aarch64)
            arch="arm64"
            ;;
        *)
            echo -e "  ${CROSS} Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac

    yq_binary="yq_${os}_${arch}"
    local download_url="https://github.com/mikefarah/yq/releases/latest/download/${yq_binary}"

    # Create install directory if it doesn't exist
    mkdir -p "$install_dir"

    # Download yq
    echo -e "  ${ARROW} Downloading yq from GitHub..."
    if curl -fsSL "$download_url" -o "${install_dir}/yq"; then
        chmod +x "${install_dir}/yq"
        echo -e "  ${CHECK} yq installed to ${install_dir}/yq"

        # Add to PATH for current session
        export PATH="${install_dir}:$PATH"

        # Check if ~/.local/bin is in PATH, if not suggest adding it
        if [[ ":$PATH:" != *":${install_dir}:"* ]]; then
            echo ""
            echo -e "  ${WARN} Add ${CYAN}${install_dir}${NC} to your PATH:"
            echo -e "     ${DIM}echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc${NC}"
            echo -e "     ${DIM}# or for zsh: >> ~/.zshrc${NC}"
        fi

        return 0
    else
        echo -e "  ${CROSS} Failed to download yq"
        return 1
    fi
}

#######################################
# Print yq installation instructions (fallback)
#######################################
print_yq_install_instructions() {
    echo ""
    echo -e "${RED}Error: yq is required but automatic installation failed.${NC}"
    echo ""
    echo -e "${BOLD}Install yq manually:${NC}"
    echo ""

    # Detect OS and provide appropriate instructions
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "  ${CYAN}macOS (Homebrew):${NC}"
        echo -e "    brew install yq"
    elif [[ -f /etc/debian_version ]]; then
        echo -e "  ${CYAN}Debian/Ubuntu:${NC}"
        echo -e "    sudo apt update && sudo apt install yq"
        echo ""
        echo -e "  Or install latest version:"
        echo -e "    sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq"
        echo -e "    sudo chmod +x /usr/bin/yq"
    elif [[ -f /etc/redhat-release ]]; then
        echo -e "  ${CYAN}RHEL/CentOS/Fedora:${NC}"
        echo -e "    sudo dnf install yq"
        echo ""
        echo -e "  Or install latest version:"
        echo -e "    sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq"
        echo -e "    sudo chmod +x /usr/bin/yq"
    else
        echo -e "  ${CYAN}Using Go:${NC}"
        echo -e "    go install github.com/mikefarah/yq/v4@latest"
        echo ""
        echo -e "  ${CYAN}Manual download:${NC}"
        echo -e "    https://github.com/mikefarah/yq/releases"
    fi
    echo ""
}

#######################################
# Check if git is installed
# Returns:
#   0 if git is available, 1 otherwise
#######################################
check_git() {
    if command -v git &> /dev/null; then
        log debug "git found: $(which git)"
        return 0
    else
        return 1
    fi
}

#######################################
# Check if curl is installed
# Returns:
#   0 if curl is available, 1 otherwise
#######################################
check_curl() {
    if command -v curl &> /dev/null; then
        log debug "curl found: $(which curl)"
        return 0
    else
        return 1
    fi
}

#######################################
# Check all required dependencies
#######################################
check_dependencies() {
    local missing=false

    # Check curl first (needed for yq installation)
    if ! check_curl; then
        echo -e "${RED}Error: curl is required but not installed.${NC}" >&2
        missing=true
    fi

    if ! check_git; then
        echo -e "${RED}Error: git is required but not installed.${NC}" >&2
        missing=true
    fi

    # Check yq and auto-install if missing
    if ! check_yq; then
        if ! install_yq; then
            print_yq_install_instructions
            missing=true
        fi
    fi

    if [[ "$missing" == "true" ]]; then
        exit 1
    fi

    log debug "All dependencies satisfied"
}

#######################################
# Check if current directory is a git repository
# Returns:
#   0 if in a git repo, 1 otherwise
#######################################
is_git_repo() {
    git rev-parse --is-inside-work-tree &> /dev/null
}

#######################################
# Get git remote URL
# Arguments:
#   $1 - Remote name (default: origin)
# Outputs:
#   Remote URL
#######################################
get_git_remote_url() {
    local remote="${1:-origin}"
    git remote get-url "$remote" 2>/dev/null || echo ""
}

#######################################
# Parse GitLab project info from remote URL
# Arguments:
#   $1 - Git remote URL
# Outputs:
#   Space-separated: gitlab_host project_path
#######################################
parse_gitlab_url() {
    local url="$1"
    local host=""
    local path=""

    # Handle SSH format: git@gitlab.com:namespace/project.git
    if [[ "$url" =~ ^git@([^:]+):(.+)\.git$ ]]; then
        host="${BASH_REMATCH[1]}"
        path="${BASH_REMATCH[2]}"
    # Handle HTTPS format: https://gitlab.com/namespace/project.git
    elif [[ "$url" =~ ^https?://([^/]+)/(.+)(\.git)?$ ]]; then
        host="${BASH_REMATCH[1]}"
        path="${BASH_REMATCH[2]}"
        path="${path%.git}"  # Remove .git suffix if present
    fi

    echo "$host $path"
}

#######################################
# URL encode a string
# Arguments:
#   $1 - String to encode
# Outputs:
#   URL encoded string
#######################################
urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] )
                o="$c"
                ;;
            * )
                printf -v o '%%%02x' "'$c"
                ;;
        esac
        encoded+="$o"
    done
    echo "$encoded"
}

#######################################
# Confirm action with user
# Arguments:
#   $1 - Prompt message
# Returns:
#   0 if user confirms, 1 otherwise
#######################################
confirm() {
    local prompt="$1"
    local response

    echo -en "  ${prompt} [y/N] "
    read -r response

    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

#######################################
# Read file content safely
# Arguments:
#   $1 - File path
# Outputs:
#   File content or empty string
#######################################
read_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cat "$file"
    else
        echo ""
    fi
}

#######################################
# Backup file before modification
# Arguments:
#   $1 - File path
#######################################
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log debug "Backed up $file to $backup"
    fi
}
