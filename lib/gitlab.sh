#!/usr/bin/env bash
#
# GitLab CI/CD setup functions for Claude Code
#

# GitLab API base URL
GITLAB_API_URL=""
GITLAB_PROJECT_ID=""
GITLAB_PROJECT_PATH=""
GITLAB_HOST=""

#######################################
# Detect GitLab project information
#######################################
detect_gitlab_project() {
    step 1 4 "Detecting project..."

    if ! is_git_repo; then
        log error "Not a git repository. Please run this from your project directory."
        exit 1
    fi

    local remote_url
    remote_url=$(get_git_remote_url)

    if [[ -z "$remote_url" ]]; then
        log error "No git remote found. Please set up a git remote first."
        exit 1
    fi

    log debug "Remote URL: $remote_url"

    # Parse GitLab URL
    local parsed
    parsed=$(parse_gitlab_url "$remote_url")
    GITLAB_HOST=$(echo "$parsed" | cut -d' ' -f1)
    GITLAB_PROJECT_PATH=$(echo "$parsed" | cut -d' ' -f2-)

    if [[ -z "$GITLAB_HOST" || -z "$GITLAB_PROJECT_PATH" ]]; then
        log error "Could not parse GitLab project from remote URL: $remote_url"
        exit 1
    fi

    # Set API URL
    GITLAB_API_URL="https://${GITLAB_HOST}/api/v4"

    log success "GitLab host: ${CYAN}${GITLAB_HOST}${NC}"
    log success "Project: ${CYAN}${GITLAB_PROJECT_PATH}${NC}"

    # Check for existing .gitlab-ci.yml
    if [[ -f ".gitlab-ci.yml" ]]; then
        log success "Existing .gitlab-ci.yml found"
    else
        log info "No existing .gitlab-ci.yml (will create new)"
    fi
}

#######################################
# Get the Claude job template based on provider
# Outputs:
#   YAML content for the claude job
#######################################
get_claude_job_template() {
    local template_file="$SCRIPT_DIR/templates/gitlab-claude-job.yml"

    if [[ ! -f "$template_file" ]]; then
        log error "Template file not found: $template_file"
        exit 1
    fi

    local template
    template=$(cat "$template_file")

    # Modify template based on provider
    case "$PROVIDER" in
        anthropic)
            # Default template is for anthropic, just return it
            echo "$template"
            ;;
        bedrock)
            # Add AWS Bedrock specific configuration
            echo "$template" | yq eval '
                .claude.before_script += ["pip install --no-cache-dir awscli"] |
                .claude.variables.CLAUDE_CODE_USE_BEDROCK = "1" |
                .claude.variables.AWS_REGION = "'"${REGION}"'"
            ' -
            ;;
        vertex)
            # Add Google Vertex AI specific configuration
            echo "$template" | yq eval '
                .claude.variables.CLAUDE_CODE_USE_VERTEX = "1" |
                .claude.variables.CLOUD_ML_REGION = "'"${REGION}"'"
            ' -
            ;;
    esac
}

#######################################
# Merge Claude job into existing .gitlab-ci.yml
#######################################
merge_gitlab_ci() {
    step 2 4 "Updating CI/CD configuration..."

    local ci_file=".gitlab-ci.yml"
    local claude_job
    claude_job=$(get_claude_job_template)

    if [[ "${DRY_RUN}" == "true" ]]; then
        log info "Dry run - showing changes that would be made:"
        echo ""
        echo -e "${DIM}--- New claude job to be added ---${NC}"
        echo "$claude_job"
        echo -e "${DIM}--- End of changes ---${NC}"
        return 0
    fi

    if [[ -f "$ci_file" ]]; then
        # Backup existing file
        backup_file "$ci_file"

        # Check if claude job already exists
        if yq eval '.claude' "$ci_file" 2>/dev/null | grep -q -v "null"; then
            if [[ "${FORCE}" == "true" ]]; then
                log warn "Overwriting existing claude job (--force)"
            else
                log warn "Claude job already exists in $ci_file"
                if ! confirm "Overwrite existing claude job?"; then
                    log info "Skipping CI configuration update"
                    return 0
                fi
            fi
            # Remove existing claude job before adding new one
            yq eval 'del(.claude)' -i "$ci_file"
        fi

        # Add 'ai' to stages if not present
        local has_ai_stage
        has_ai_stage=$(yq eval '.stages[] | select(. == "ai")' "$ci_file" 2>/dev/null || echo "")

        if [[ -z "$has_ai_stage" ]]; then
            # Check if stages key exists
            local has_stages
            has_stages=$(yq eval '.stages' "$ci_file" 2>/dev/null || echo "null")

            if [[ "$has_stages" == "null" ]]; then
                # Create stages array with 'ai'
                yq eval '.stages = ["ai"]' -i "$ci_file"
                log success "Created stages with 'ai'"
            else
                # Append 'ai' to existing stages
                yq eval '.stages += ["ai"]' -i "$ci_file"
                log success "Added 'ai' to stages"
            fi
        else
            log info "'ai' stage already exists"
        fi

        # Merge claude job into existing file
        # Write template to temp file first
        local temp_job
        temp_job=$(mktemp)
        echo "$claude_job" > "$temp_job"

        # Extract just the claude job and merge
        yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$ci_file" "$temp_job" > "${ci_file}.tmp"
        mv "${ci_file}.tmp" "$ci_file"
        rm -f "$temp_job"

        log success "Merged claude job into $ci_file"
    else
        # Create new .gitlab-ci.yml with stages header
        {
            echo "stages:"
            echo "  - ai"
            echo ""
            echo "$claude_job"
        } > "$ci_file"
        log success "Created new $ci_file"
    fi
}

#######################################
# Set GitLab CI/CD variable via API
# Arguments:
#   $1 - Variable key
#   $2 - Variable value
#   $3 - Masked (true/false)
#   $4 - Protected (true/false)
#######################################
set_gitlab_variable() {
    local key="$1"
    local value="$2"
    local masked="${3:-true}"
    local protected="${4:-false}"

    if [[ -z "$GITLAB_TOKEN" ]]; then
        log debug "No GitLab token provided, skipping variable API"
        return 1
    fi

    local encoded_path
    encoded_path=$(urlencode "$GITLAB_PROJECT_PATH")

    local api_url="${GITLAB_API_URL}/projects/${encoded_path}/variables"

    log debug "Setting variable $key via API: $api_url"

    # Check if variable already exists
    local existing
    existing=$(curl -s --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
        "${api_url}/${key}" 2>/dev/null || echo "")

    local http_method="POST"
    local endpoint="$api_url"

    if echo "$existing" | grep -q "\"key\":\"${key}\""; then
        # Variable exists, update it
        http_method="PUT"
        endpoint="${api_url}/${key}"
        log debug "Variable $key exists, updating"
    fi

    local response
    response=$(curl -s -X "$http_method" \
        --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
        --form "key=${key}" \
        --form "value=${value}" \
        --form "masked=${masked}" \
        --form "protected=${protected}" \
        "$endpoint" 2>&1)

    if echo "$response" | grep -q "\"key\":\"${key}\""; then
        return 0
    else
        log debug "API response: $response"
        return 1
    fi
}

#######################################
# Setup GitLab CI/CD variables
#######################################
setup_gitlab_variables() {
    step 3 4 "Configuring CI/CD variables..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        log info "Dry run - would configure the following variables:"
        case "$PROVIDER" in
            anthropic)
                log info "  ANTHROPIC_API_KEY (masked, protected)"
                ;;
            bedrock)
                log info "  AWS_ROLE_TO_ASSUME"
                log info "  AWS_REGION"
                ;;
            vertex)
                log info "  GCP_WORKLOAD_IDENTITY_PROVIDER"
                log info "  GCP_SERVICE_ACCOUNT"
                log info "  CLOUD_ML_REGION"
                ;;
        esac
        return 0
    fi

    case "$PROVIDER" in
        anthropic)
            if [[ -n "$API_KEY" ]]; then
                if [[ -n "$GITLAB_TOKEN" ]]; then
                    if set_gitlab_variable "ANTHROPIC_API_KEY" "$API_KEY" "true" "true"; then
                        log success "ANTHROPIC_API_KEY configured (masked)"
                    else
                        log warn "Could not set variable via API"
                        print_manual_variable_instructions "ANTHROPIC_API_KEY" "$API_KEY"
                    fi
                else
                    print_manual_variable_instructions "ANTHROPIC_API_KEY" "$API_KEY"
                fi
            else
                log warn "No API key provided"
                echo ""
                echo -e "  ${BOLD}Add your API key manually:${NC}"
                echo -e "  1. Go to ${CYAN}https://${GITLAB_HOST}/${GITLAB_PROJECT_PATH}/-/settings/ci_cd${NC}"
                echo -e "  2. Expand 'Variables' section"
                echo -e "  3. Add variable:"
                echo -e "     Key: ${CYAN}ANTHROPIC_API_KEY${NC}"
                echo -e "     Value: ${DIM}your-api-key${NC}"
                echo -e "     ${DIM}✓ Mask variable${NC}"
                echo -e "     ${DIM}✓ Protect variable (optional)${NC}"
            fi
            ;;
        bedrock)
            log info "AWS Bedrock uses OIDC authentication"
            echo ""
            echo -e "  ${BOLD}Configure AWS OIDC:${NC}"
            echo -e "  1. Set up GitLab as OIDC provider in AWS IAM"
            echo -e "  2. Create IAM role with Bedrock permissions"
            echo -e "  3. Add these variables in GitLab CI/CD settings:"
            echo -e "     ${CYAN}AWS_ROLE_TO_ASSUME${NC}: arn:aws:iam::xxx:role/your-role"
            echo -e "     ${CYAN}AWS_REGION${NC}: ${REGION}"
            echo ""
            echo -e "  ${DIM}Docs: https://docs.gitlab.com/ee/ci/cloud_services/aws/${NC}"
            ;;
        vertex)
            log info "Google Vertex AI uses Workload Identity Federation"
            echo ""
            echo -e "  ${BOLD}Configure GCP Workload Identity:${NC}"
            echo -e "  1. Set up Workload Identity Federation in GCP"
            echo -e "  2. Create service account with Vertex AI permissions"
            echo -e "  3. Add these variables in GitLab CI/CD settings:"
            echo -e "     ${CYAN}GCP_WORKLOAD_IDENTITY_PROVIDER${NC}: projects/xxx/..."
            echo -e "     ${CYAN}GCP_SERVICE_ACCOUNT${NC}: sa@project.iam.gserviceaccount.com"
            echo -e "     ${CYAN}CLOUD_ML_REGION${NC}: ${REGION}"
            echo ""
            echo -e "  ${DIM}Docs: https://docs.gitlab.com/ee/ci/cloud_services/google_cloud/${NC}"
            ;;
    esac
}

#######################################
# Print manual variable setup instructions
# Arguments:
#   $1 - Variable key
#   $2 - Variable value (will be partially masked)
#######################################
print_manual_variable_instructions() {
    local key="$1"
    local value="$2"

    # Mask most of the value for display
    local masked_value
    if [[ ${#value} -gt 8 ]]; then
        masked_value="${value:0:4}...${value: -4}"
    else
        masked_value="****"
    fi

    echo ""
    echo -e "  ${BOLD}Add variable manually:${NC}"
    echo -e "  1. Go to ${CYAN}https://${GITLAB_HOST}/${GITLAB_PROJECT_PATH}/-/settings/ci_cd${NC}"
    echo -e "  2. Expand 'Variables' section"
    echo -e "  3. Add variable:"
    echo -e "     Key: ${CYAN}${key}${NC}"
    echo -e "     Value: ${DIM}${masked_value}${NC}"
    echo -e "     ${DIM}✓ Mask variable${NC}"
}

#######################################
# Verify setup
#######################################
verify_setup() {
    step 4 4 "Verifying setup..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        log info "Dry run complete - no changes were made"
        return 0
    fi

    # Check if .gitlab-ci.yml exists and has claude job
    if [[ -f ".gitlab-ci.yml" ]]; then
        local has_claude
        has_claude=$(yq eval '.claude' ".gitlab-ci.yml" 2>/dev/null || echo "null")

        if [[ "$has_claude" != "null" ]]; then
            log success "Claude job configured in .gitlab-ci.yml"
        else
            log warn "Claude job not found in .gitlab-ci.yml"
        fi
    else
        log error ".gitlab-ci.yml not found"
    fi
}

#######################################
# Main GitLab setup function
#######################################
setup_gitlab() {
    detect_gitlab_project
    merge_gitlab_ci
    setup_gitlab_variables
    verify_setup
}
