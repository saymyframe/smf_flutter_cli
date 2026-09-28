// A module of your own on the module model: it sets up the logging package
// in the Flutter apps that SMF generates.
//
// The module adds the package to the dependencies of the app, puts a line
// into the early phase of `bootstrap()` that prints every log record, and
// adds a section to the README of the app. It names no other module, so it
// fits any app.
//
// To offer it in `smf create`, pass it to `runCli` of smf_flutter_cli
// together with the modules of SMF. The example of smf_pipeline tests it
// with the contract harness. See https://doc.saymyframe.com/extending.
import 'package:smf_contracts/smf_contracts.dart';

/// Sets up the logging package in the app.
final class LoggingModule extends SmfModule {
  /// Creates the module.
  const LoggingModule();

  /// The id of the module, which `smf create -m logging` takes.
  static const id = ModuleId('logging');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Logging with the logging package',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        const PubspecContribution.hosted('logging', '^1.3.0'),
        const SocketContribution.code(
          AppEntryRole.bootstrapEarly,
          Fragment(
            'Logger.root.onRecord.listen((record) => '
            r"debugPrint('${record.level.name}: ${record.message}'));",
            imports: [
              ImportRef(
                'package:flutter/foundation.dart',
                show: ['debugPrint'],
              ),
              ImportRef('package:logging/logging.dart', show: ['Logger']),
            ],
          ),
        ),
        AppEntryRole.readmeSections.entry(
          'Logging',
          'The app logs with the [logging](https://pub.dev/packages/logging) '
              'package: create a `Logger` for each class, and `bootstrap()` '
              'prints every record.',
        ),
      ];
}
