# Fixtures of the pipeline tests

These packages are **not modules to use**. They exist only to test the SMF pipeline and the lego model: the tests of `smf_pipeline` and the "fixture registry" line of the Flutter job generate apps from them.

Together they use every mechanism of the lego model that no real module uses yet (basket B of the lego plan): every kind of socket and merge policy, `when`, variants, a third-party role, two roles with the same data type, a provider of two roles, a DI container with configurable capabilities, a feature with a composition file, every DI capability, code generation, navigator observers, the navigation facade, asynchronous service initialization, and the `flutter:` section of the pubspec.

Rules:

- Every fixture is a package of the workspace with `publish_to: none`, so `melos` bundles its bricks and analyzes it.
- Fixtures are never part of the CLI's registry or of any published package; `smf_pipeline` excludes `test/fixtures/` from its archive.
- A fixture follows the rules of a real module, so the contract harness checks it like one.
