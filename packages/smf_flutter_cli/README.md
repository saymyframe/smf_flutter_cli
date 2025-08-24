# smf_flutter_cli

Command line interface for SMF Flutter projects: scaffold, configure modules, and generate code.

## Install
```bash
dart pub global activate smf_flutter_cli
```

## Quick start

Interactive (you will be prompted for missing values):
```bash
smf create my_app
```

Non-interactive (fully scripted):
```bash
smf create my_cli_test_app \
  -m firebase_analytics,home,get_it,go_router \
  --route /home \
  --org com.saymyframe
```

## Options

- `-o, --output` (default: `./`)
  - Output path where the project will be created.

- `-m, --modules`
  - Comma-separated list of modules to include. If omitted, you will be prompted to select modules interactively.
  - Allowed module identifiers: `firebase_core`, `firebase_analytics`, `get_it`, `event_bus`, `go_router`, `home`.

- `-r, --route`
  - Initial route for the generated app (e.g., `/home`, `/dashboard`). If omitted, and multiple modules can provide an initial route, you will be prompted to choose one.

- `--org`
  - Organization (reverse-DNS) used to generate the package/bundle id, e.g., `com.saymyframe` → `com.saymyframe.my_app`.

### Global flags

- `--verbose` — enable verbose logging
- `-v, --version` — print CLI version

Note: SMF core modules required by the system are added automatically when generating a project.

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/SayMyFrame/smf_flutter_cli/issues)

## License
See LICENSE.
