# Contributing to setup-cc-gitlab

First off, thank you for considering contributing to setup-cc-gitlab! It's people like you that make this tool better for everyone.

## Code of Conduct

By participating in this project, you are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (command you ran, error message, etc.)
- **Describe the behavior you observed and what you expected**
- **Include your environment details** (OS, bash version, yq version)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description of the proposed feature**
- **Explain why this enhancement would be useful**
- **List any alternatives you've considered**

### Pull Requests

1. Fork the repo and create your branch from `main`
2. Make your changes
3. Test your changes thoroughly
4. Update documentation if needed
5. Submit your pull request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/setup-cc-gitlab.git
cd setup-cc-gitlab

# Create a branch for your feature
git checkout -b feature/your-feature-name

# Make your changes and test
./setup.sh --platform gitlab --dry-run
```

## Style Guide

### Bash Style

- Use `#!/usr/bin/env bash` shebang
- Use `set -eo pipefail` for error handling
- Quote variables: `"$variable"` not `$variable`
- Use `[[ ]]` for conditionals, not `[ ]`
- Use meaningful function and variable names
- Add comments for complex logic

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests when relevant

Example:
```
Add support for GitHub Actions

- Add lib/github.sh for GitHub-specific logic
- Add templates/github-claude.yml
- Update README with GitHub examples

Closes #123
```

## Project Structure

```
setup-cc-gitlab/
├── setup.sh                    # Main entry point
├── lib/
│   ├── common.sh              # Shared utilities
│   ├── gitlab.sh              # GitLab-specific logic
│   └── github.sh              # GitHub-specific logic (planned)
├── templates/
│   └── gitlab-claude-job.yml  # CI/CD templates
└── examples/                   # Example configurations
```

## Testing

Before submitting a PR, please test:

1. **Dry run mode**: `./setup.sh --platform gitlab --dry-run`
2. **Fresh install**: Test on a repo without `.gitlab-ci.yml`
3. **Existing config**: Test on a repo with existing `.gitlab-ci.yml`
4. **Different providers**: Test with `--provider anthropic/bedrock/vertex`

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

Thank you for contributing!
