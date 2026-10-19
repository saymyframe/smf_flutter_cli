import 'dart:convert';
import 'dart:io';

import 'package:smf_flutter_cli/setup_steps.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';

/// Writes `setup_steps.json` of the package, the catalog of the steps by
/// hand of the modules of `smf create`: the steps of their apps now, and
/// the retired steps of the catalog that the file has, with each step that
/// left the apps since (see `SetupCatalog.next`). Prints what changed.
///
/// Run it in `packages/smf_flutter_cli` after a change of the steps of a
/// module, `dart run tool/setup_steps.dart`, and copy the file to
/// `src/data/setup-steps.json` of the site of SMF, which needs a guide for
/// each step. `test/setup_steps_test.dart` fails until the file is written.
Future<void> main() async {
  final file = File.fromUri(Platform.script.resolve('../$setupStepsFile'));
  final before = file.existsSync()
      ? file.readAsStringSync().replaceAll('\r\n', '\n')
      : null;
  final previous =
      before == null ? const SetupCatalog() : SetupCatalog.parse(before);
  final catalog = previous.next(await setupStepsOf(smfModules));
  final text = catalog.render();
  final size = '${catalog.steps.length} steps, '
      '${catalog.retired.length} retired';
  if (text == before) {
    stdout.writeln('$setupStepsFile is up to date: $size.');
    return;
  }
  file.writeAsStringSync(text);
  final changes = before == null ? 'a new file' : _changes(previous, catalog);
  stdout
    ..writeln('Wrote $setupStepsFile: $size; $changes.')
    ..writeln(
      'Copy it to src/data/setup-steps.json of the site of SMF, with a guide '
      'for each new step.',
    );
}

/// What changed from [before] to [after]: the new, changed and retired
/// steps, or the order of the steps or the form of the file.
String _changes(SetupCatalog before, SetupCatalog after) {
  Map<String, String> byId(SetupCatalog catalog) => {
        for (final step in catalog.steps) step.id: jsonEncode(step.toJson()),
      };
  final was = byId(before);
  final now = byId(after);
  final added = [...now.keys.where((id) => !was.containsKey(id))];
  final changed = [
    ...now.keys.where((id) => was.containsKey(id) && was[id] != now[id]),
  ];
  final retired = [...was.keys.where((id) => !now.containsKey(id))];
  final changes = [
    if (added.isNotEmpty) 'new ${added.join(', ')}',
    if (changed.isNotEmpty) 'changed ${changed.join(', ')}',
    if (retired.isNotEmpty) 'retired ${retired.join(', ')}',
  ];
  return changes.isEmpty
      ? 'the order of the steps or the form of the file changed'
      : changes.join('; ');
}
