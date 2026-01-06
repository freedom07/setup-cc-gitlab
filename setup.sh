#!/usr/bin/env bash
#
# Claude Code CI Setup
# Easily configure Claude Code for GitLab CI/CD (GitHub Actions coming soon)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/freedom07/setup-cc-gitlab/main/setup.sh | bash -s -- --platform gitlab
#
# Or download and run locally:
#   ./setup.sh --platform gitlab --provider anthropic --api-key "sk-ant-xxx"
#

set -euo pipefail

# Script directory detection (works for both local and curl | bash)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # When piped through curl, create temp directory and download libs
    SCRIPT_DIR="$(mktemp -d)"
    REMOTE_BASE="https://raw.githubusercontent.com/freedom07/setup-cc-gitlab/main"
    DOWNLOAD_LIBS=true
fi

# Version
VERSION="0.1.0"

# Default values
PLATFORM=""
PROVIDER="anthropic"
API_KEY=""
REGION=""
PROJECT_URL=""
GITLAB_TOKEN=""
DRY_RUN=false
FORCE=false
VERBOSE=false

# Colors (will be overridden by common.sh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

#######################################
# Print usage information
#######################################
usage() {
    cat << EOF
${BOLD}Claude Code CI Setup${NC} v${VERSION}

Setup Claude Code for your CI/CD pipeline with a single command.

${BOLD}USAGE:${NC}
    setup.sh --platform <platform> [OPTIONS]

${BOLD}REQUIRED:${NC}
    --platform <gitlab|github>      CI/CD platform to configure

${BOLD}OPTIONS:${NC}
    --provider <provider>           API provider: anthropic (default), bedrock, vertex
    --api-key <key>                 API key (will be stored as masked CI/CD variable)
    --api-key-stdin                 Read API key from stdin (more secure)
    --region <region>               AWS/GCP region (required for bedrock/vertex)
    --project-url <url>             GitLab/GitHub project URL (auto-detected from git remote)
    --gitlab-token <token>          GitLab personal access token (for Variables API)
    --dry-run                       Preview changes without applying them
    --force                         Overwrite existing configuration
    --verbose                       Enable verbose output
    -h, --help                      Show this help message
    -v, --version                   Show version

${BOLD}EXAMPLES:${NC}
    # Basic GitLab setup with Anthropic API
    ./setup.sh --platform gitlab --api-key "sk-ant-xxx"

    # GitLab with AWS Bedrock
    ./setup.sh --platform gitlab --provider bedrock --region us-west-2

    # Dry run to preview changes
    ./setup.sh --platform gitlab --dry-run

    # Read API key securely from stdin
    echo "sk-ant-xxx" | ./setup.sh --platform gitlab --api-key-stdin

${BOLD}DOCUMENTATION:${NC}
    https://code.claude.com/docs/gitlab-ci-cd

EOF
}

#######################################
# Print version
#######################################
version() {
    echo "Claude Code CI Setup v${VERSION}"
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --platform)
                PLATFORM="$2"
                shift 2
                ;;
            --provider)
                PROVIDER="$2"
                shift 2
                ;;
            --api-key)
                API_KEY="$2"
                shift 2
                ;;
            --api-key-stdin)
                read -r API_KEY
                shift
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --project-url)
                PROJECT_URL="$2"
                shift 2
                ;;
            --gitlab-token)
                GITLAB_TOKEN="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                version
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}" >&2
                usage
                exit 1
                ;;
        esac
    done
}

#######################################
# Validate arguments
#######################################
validate_args() {
    # Platform is required
    if [[ -z "$PLATFORM" ]]; then
        echo -e "${RED}Error: --platform is required${NC}" >&2
        echo "Run with --help for usage information"
        exit 1
    fi

    # Validate platform
    if [[ "$PLATFORM" != "gitlab" && "$PLATFORM" != "github" ]]; then
        echo -e "${RED}Error: Invalid platform '$PLATFORM'. Must be 'gitlab' or 'github'${NC}" >&2
        exit 1
    fi

    # GitHub not yet supported
    if [[ "$PLATFORM" == "github" ]]; then
        echo -e "${YELLOW}GitHub Actions support is coming soon!${NC}"
        echo "For now, please use GitLab CI/CD."
        exit 0
    fi

    # Validate provider
    if [[ "$PROVIDER" != "anthropic" && "$PROVIDER" != "bedrock" && "$PROVIDER" != "vertex" ]]; then
        echo -e "${RED}Error: Invalid provider '$PROVIDER'. Must be 'anthropic', 'bedrock', or 'vertex'${NC}" >&2
        exit 1
    fi

    # Region required for bedrock/vertex
    if [[ "$PROVIDER" != "anthropic" && -z "$REGION" ]]; then
        echo -e "${RED}Error: --region is required for provider '$PROVIDER'${NC}" >&2
        exit 1
    fi
}

#######################################
# Download library files if running via curl
#######################################
download_libs() {
    if [[ "${DOWNLOAD_LIBS:-false}" == "true" ]]; then
        echo -e "${CYAN}Downloading library files...${NC}"
        mkdir -p "$SCRIPT_DIR/lib" "$SCRIPT_DIR/templates"

        curl -fsSL "$REMOTE_BASE/lib/common.sh" -o "$SCRIPT_DIR/lib/common.sh"
        curl -fsSL "$REMOTE_BASE/lib/gitlab.sh" -o "$SCRIPT_DIR/lib/gitlab.sh"
        curl -fsSL "$REMOTE_BASE/templates/gitlab-claude-job.yml" -o "$SCRIPT_DIR/templates/gitlab-claude-job.yml"
    fi
}

#######################################
# Source library files
#######################################
source_libs() {
    if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
        # shellcheck source=lib/common.sh
        source "$SCRIPT_DIR/lib/common.sh"
    else
        echo -e "${RED}Error: lib/common.sh not found${NC}" >&2
        exit 1
    fi
}

#######################################
# Cleanup temp directory on exit
#######################################
cleanup() {
    if [[ "${DOWNLOAD_LIBS:-false}" == "true" && -d "$SCRIPT_DIR" ]]; then
        rm -rf "$SCRIPT_DIR"
    fi
}

#######################################
# Main entry point
#######################################
main() {
    parse_args "$@"
    validate_args

    # Download libs if running via curl
    download_libs

    # Source common library
    source_libs

    # Check dependencies
    check_dependencies

    # Print header
    print_header

    # Run platform-specific setup
    case $PLATFORM in
        gitlab)
            # shellcheck source=lib/gitlab.sh
            source "$SCRIPT_DIR/lib/gitlab.sh"
            setup_gitlab
            ;;
        github)
            echo -e "${YELLOW}GitHub Actions support coming soon!${NC}"
            exit 0
            ;;
    esac

    # Print completion message
    print_completion
}

# Set trap for cleanup
trap cleanup EXIT

# Run main
main "$@"
