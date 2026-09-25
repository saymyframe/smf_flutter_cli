/// The contract test harness of the lego model: checks that modules and
/// role templates follow the rules of their roles.
///
/// It runs without `package:test`, so both the tests of this package and the
/// contract tests of the CLI can use it.
library;

export 'src/collector.dart' show Collected, Collection;
export 'src/resolver.dart'
    show
        DependencyOf,
        ProviderOf,
        Requested,
        Resolution,
        ResolvedModule,
        SelectionReason;
export 'src/templates.dart';
export 'src/testing/file_indexer.dart';
export 'src/testing/harness.dart';
export 'src/validation.dart' show ValidationResult;
