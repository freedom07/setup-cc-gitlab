# Claude Code CI Setup

Setup [Claude Code](https://code.claude.com) for your CI/CD pipeline with a single command.

## Quick Start

### One-liner (Remote Execution)

```bash
curl -fsSL https://raw.githubusercontent.com/freedom07/setup-cc-gitlab/main/setup.sh | bash -s -- \
  --platform gitlab \
  --api-key "sk-ant-xxx"
```

### Local Installation

```bash
# Clone the repository
git clone https://github.com/freedom07/setup-cc-gitlab.git
cd cc-ci-setup

# Run setup in your project directory
./setup.sh --platform gitlab --api-key "sk-ant-xxx"
```

## Prerequisites

- **git** - Version control
- **curl** - HTTP client
- **yq** - YAML processor (auto-installed if missing)

> **Note**: yq will be automatically downloaded and installed to `~/.local/bin` if not found on your system.

## Usage

```bash
setup.sh --platform <platform> [OPTIONS]
```

### Required

| Option | Description |
|--------|-------------|
| `--platform <gitlab\|github>` | CI/CD platform to configure |

### Options

| Option | Description |
|--------|-------------|
| `--provider <provider>` | API provider: `anthropic` (default), `bedrock`, `vertex` |
| `--api-key <key>` | API key (stored as masked CI/CD variable) |
| `--api-key-stdin` | Read API key from stdin (more secure) |
| `--region <region>` | AWS/GCP region (required for bedrock/vertex) |
| `--project-url <url>` | GitLab project URL (auto-detected from git remote) |
| `--gitlab-token <token>` | GitLab PAT for Variables API |
| `--dry-run` | Preview changes without applying |
| `--force` | Overwrite existing configuration |
| `--verbose` | Enable verbose output |
| `-h, --help` | Show help message |
| `-v, --version` | Show version |

## Examples

### Basic GitLab Setup (Anthropic API)

```bash
./setup.sh --platform gitlab --api-key "sk-ant-api03-xxx"
```

### GitLab with AWS Bedrock

```bash
./setup.sh --platform gitlab --provider bedrock --region us-west-2
```

### GitLab with Google Vertex AI

```bash
./setup.sh --platform gitlab --provider vertex --region us-east5
```

### Secure API Key Input

```bash
# Read from stdin (doesn't appear in shell history)
echo "sk-ant-xxx" | ./setup.sh --platform gitlab --api-key-stdin

# Or use environment variable
./setup.sh --platform gitlab --api-key "$ANTHROPIC_API_KEY"
```

### Auto-configure GitLab Variables

```bash
# Provide GitLab token to automatically set CI/CD variables
./setup.sh --platform gitlab \
  --api-key "sk-ant-xxx" \
  --gitlab-token "glpat-xxx"
```

### Preview Changes (Dry Run)

```bash
./setup.sh --platform gitlab --dry-run
```

## What It Does

1. **Detects your project** - Reads git remote to find GitLab project info
2. **Updates `.gitlab-ci.yml`** - Adds `ai` stage and `claude` job (merges with existing config)
3. **Configures variables** - Sets up `ANTHROPIC_API_KEY` as masked CI/CD variable
4. **Verifies setup** - Confirms configuration is complete

## Supported Providers

### Anthropic API (Default)

Direct API access using `ANTHROPIC_API_KEY`.

```bash
./setup.sh --platform gitlab --api-key "sk-ant-xxx"
```

### AWS Bedrock

Uses OIDC authentication. Requires:
- GitLab as OIDC provider in AWS IAM
- IAM role with Bedrock permissions
- CI/CD variables: `AWS_ROLE_TO_ASSUME`, `AWS_REGION`

```bash
./setup.sh --platform gitlab --provider bedrock --region us-west-2
```

### Google Vertex AI

Uses Workload Identity Federation. Requires:
- Workload Identity Federation in GCP
- Service account with Vertex AI permissions
- CI/CD variables: `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT`, `CLOUD_ML_REGION`

```bash
./setup.sh --platform gitlab --provider vertex --region us-east5
```

## Generated Configuration

The tool generates a `.gitlab-ci.yml` with:

```yaml
stages:
  - ai

claude:
  stage: ai
  image: node:24-alpine3.21
  rules:
    - if: '$CI_PIPELINE_SOURCE == "web"'
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
  variables:
    GIT_STRATEGY: fetch
  before_script:
    - apk update
    - apk add --no-cache git curl bash
    - npm install -g @anthropic-ai/claude-code
  script:
    - /bin/gitlab-mcp-server || true
    - |
      claude \
        -p "${AI_FLOW_INPUT:-'Review this MR and implement the requested changes'}" \
        --permission-mode acceptEdits \
        --allowedTools "Bash(*) Read(*) Edit(*) Write(*) mcp__gitlab" \
        --debug
```

## Using Claude in GitLab

After setup:

1. **Commit and push** the `.gitlab-ci.yml` changes
2. **Mention `@claude`** in an MR comment or issue
3. Claude will analyze and respond with code changes

### Example Commands

```
@claude implement this feature based on the issue description
@claude fix the TypeError in the user dashboard component
@claude suggest a concrete approach to cache the results of this API call
```

## Troubleshooting

### yq not found

Install yq using one of the methods in [Prerequisites](#prerequisites).

### Could not parse GitLab project

Ensure your git remote is set correctly:

```bash
git remote -v
# Should show: origin git@gitlab.com:namespace/project.git
```

### Variables API error

If automatic variable setup fails, add variables manually:
1. Go to **Settings > CI/CD > Variables**
2. Add `ANTHROPIC_API_KEY` with your key
3. Enable **Mask variable**

## Roadmap

- [x] GitLab CI/CD support
- [ ] GitHub Actions support
- [ ] Bitbucket Pipelines support
- [ ] Interactive mode
- [ ] Custom job templates

## Documentation

- [Claude Code GitLab CI/CD](https://code.claude.com/docs/gitlab-ci-cd)
- [Claude Code Documentation](https://code.claude.com/docs)

## License

MIT
