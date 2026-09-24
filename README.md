[![pub package](https://img.shields.io/pub/v/smf_flutter_cli.svg)](https://pub.dev/packages/smf_flutter_cli)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=saymyframe_smf_flutter_cli&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=saymyframe_smf_flutter_cli)
[![status: preview](https://img.shields.io/badge/status-preview-blue.svg)](https://github.com/saymyframe/smf_flutter_cli/issues)
[![license](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Join us on Discord](https://img.shields.io/badge/Join%20us-Discord-5865F2?logo=discord&logoColor=white)](https://saymyframe.com/discord)

# SMF Flutter CLI

A comprehensive Flutter CLI tool for scaffolding and configuring Flutter applications with modular architecture.

## Overview

SMF Flutter CLI is a powerful command-line interface that helps developers quickly scaffold Flutter applications with pre-configured modules, dependencies, and best practices. It provides a modular approach to Flutter project generation, allowing developers to select only the components they need.

> Status: Alpha — Actively developed. Features are added continuously and APIs may change. Best suited for exploration and early prototypes. Feedback and contributions are welcome.

## Features

- 🚀 **Rapid Project Scaffolding**: Generate Flutter projects with pre-configured modules
- 🧩 **Modular Architecture**: Select and configure only the modules you need
- 🔧 **Smart Dependency Management**: Automatic dependency resolution and configuration
- 📱 **Flutter Best Practices**: Built-in templates following Flutter development standards
- 🔥 **Firebase Integration**: Seamless Firebase setup and configuration
- 🛣️ **Routing Solutions**: Multiple routing options including GoRouter
- 📊 **Analytics Ready**: Built-in analytics and tracking capabilities
- 🎯 **Customizable Templates**: Extensible brick-based template system

## Install
```bash
dart pub global activate smf_flutter_cli
smf --version
```

## Quick start

Interactive (you will be prompted for missing values):
```bash
smf create my_app
```

![SMF CLI Demo](https://raw.githubusercontent.com/saymyframe/.github/main/assets/smf_cli.gif)

```bash
A CLI tool by Say My Frame

Usage: smf <command> [arguments]

Global options:
-h, --help           Print this usage information.
    --verbose        Enable verbose logging.
    --strict         Enable strict mode for module compatibility checks.
-v, --version        Print the current CLI version.
    --on-conflict    Behavior when destination directory exists (replace, copy, cancel, prompt).
                     [replace, copy, cancel, prompt (default)]

Available commands:
  create   Create flutter app

Run "smf help <command>" for more information about a command.
```

Non-interactive (fully scripted):
```bash
smf create my_cli_test_app \
  -m firebase_analytics,home,get_it,go_router \
  --route /home \
  --org com.saymyframe \
  -s bloc \
  --on-conflict replace
```

## Available Modules

- **Core Flutter**: Basic Flutter project structure and configuration
- **Firebase Core**: Firebase initialization and basic setup
- **Analytics**: Analytics and tracking integration
- **GoRouter**: Advanced routing with GoRouter
- **GetIt**: Dependency injection with GetIt
- **Communication**: Inter-module communication patterns
- **Home Flutter**: Home screen and navigation templates

## Available State Manager Approach
- **BLoC**: Event–State pattern using `flutter_bloc`.
- **Riverpod**: Provider-based model using `flutter_riverpod`.

## Development

This is a monorepo managed with Melos. Every package is versioned and published to pub.dev on its own.

```
packages/
  smf_contracts/            # public API that modules implement
  smf_modules/
    smf_contribution_engine/  # AST-based code contributions
    smf_<module>/             # first-party modules (go_router, get_it, firebase_*, ...)
  smf_flutter_cli/          # the `smf` CLI
```

Dependencies only point one way: `smf_contracts` ← modules ← `smf_flutter_cli`.

To contribute:

```bash
# Install dependencies and bundle bricks
melos bootstrap
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## Support

- 📧 Email: support@saymyframe.com
- 🐛 Issues: [GitHub Issues](https://github.com/saymyframe/smf_flutter_cli/issues)
- 📖 Documentation: [SayMyFrame Docs](https://saymyframe.com)
