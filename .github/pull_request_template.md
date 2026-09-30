## Summary

Explain the change in one to three sentences.

## Scope

- Affected areas:
  - [ ] Contracts (`smf_contracts`)
  - [ ] Pipeline (`smf_pipeline`) or the contract harness
  - [ ] Modules and their bricks
  - [ ] CLI (`smf_flutter_cli`)
  - [ ] Tooling or CI
  - [ ] Docs

## Motivation and Context

Why is this change needed? What problem does it solve?

## How Has This Been Tested?

Describe tests performed (commands, scenarios, platforms). Attach screenshots/logs if helpful.

## Checklist

- [ ] Code is clean and readable; comments/strings are in English only
- [ ] `melos run check` passes: format, analyze, banlist and tests
- [ ] Tests added/updated where appropriate
- [ ] User-facing docs or READMEs updated where applicable
- [ ] Commits follow Conventional Commits, from which `melos version` writes the changelogs (don't edit them by hand)
- [ ] If bricks changed, ran `melos bootstrap` and committed the bundles
- [ ] Modules stay independent: no module refers to another it does not depend on
- [ ] Avoided module-level installation instructions; modules are integrated via the CLI

## Related Issues

Link to the issue(s) this PR closes or relates to.
