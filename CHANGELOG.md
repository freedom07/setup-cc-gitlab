# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- GitHub Actions support
- Interactive mode for guided setup
- Custom job template support

## [0.1.0] - 2025-01-06

### Added
- Initial release
- GitLab CI/CD setup with single command
- Support for multiple providers:
  - Anthropic API (default)
  - AWS Bedrock
  - Google Vertex AI
- Automatic yq installation if missing
- Merge with existing `.gitlab-ci.yml` (preserves existing stages and jobs)
- Dry-run mode for previewing changes
- GitLab Variables API integration (with `--gitlab-token`)
- Backup of existing configuration before modification

### Fixed
- Preserve existing stages when merging configuration
- Handle curl pipe execution correctly

[Unreleased]: https://github.com/freedom07/setup-cc-gitlab/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/freedom07/setup-cc-gitlab/releases/tag/v0.1.0
