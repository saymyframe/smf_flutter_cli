# Contributing to SMF Flutter CLI

Thank you for your interest in contributing to SMF Flutter CLI! This document provides guidelines and information for contributors.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

- Use the GitHub issue tracker
- Include detailed steps to reproduce the bug
- Provide your environment details (OS, Flutter version, etc.)
- Include error messages and stack traces

### Suggesting Enhancements

- Use the GitHub issue tracker with the "enhancement" label
- Describe the feature and its benefits
- Provide use cases and examples

### Submitting Code Changes

1. Fork the repository
2. Create a branch named after the change type (`git checkout -b feat/amazing-feature`, or `fix/...`, `docs/...`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all checks pass (`melos run check`)
6. Commit using [Conventional Commits](https://www.conventionalcommits.org/) (`git commit -m 'feat(go_router): add amazing feature'`)
7. Push to the branch (`git push origin feat/amazing-feature`)
8. Open a Pull Request

## Development Setup

1. Clone the repository
2. Install dependencies and bundle bricks: `melos bootstrap`
3. Run all checks: `melos run check` (format, analyze, brick hooks, tests)

The repository layout, the module-independence rules and the conventions for generated files and tests are described in [AGENTS.md](AGENTS.md). It is written for AI coding agents but is just as useful for people.

## Code Style

- Follow the Dart style guide; CI checks formatting with Dart 3.12.2
- `very_good_analysis` is enabled in every package
- Use Conventional Commits with the package as scope (`fix(contracts): ...`); versions and changelogs are generated from them
- Add tests for new functionality

## Copyright and Licensing

By contributing to this project, you agree that your contributions will be licensed under the Apache License, Version 2.0.

When submitting code, please ensure you have the right to license your contributions under the Apache License.

## Questions?

If you have questions about contributing, please contact us at support@saymyframe.com or open an issue on GitHub.

Thank you for contributing to SMF Flutter CLI!
