import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';

/// Prints, as JSON, the arguments of `smf create` that generate each app
/// with every module of the modules of `smf create` in the directory given
/// as its only argument, one for each combination of the providers of the
/// roles that take one, with the name of its case of the contract harness:
/// `[{"name": "every module (bloc)", "arguments": ["create", "app_1", …]}]`.
/// The apps are named app_1, app_2 and so on, and get the arguments that
/// the matrix of CI gives `smf create`, but with the full `dart fix`, as a
/// user runs it. None of them is the app of another value of a mode option
/// of a role, which the matrix has next to them: each gets no value of such
/// an option, and so the one of an app that a user generates without it.
///
/// CI runs it in a package of its own that depends on the release of
/// smf_flutter_cli that it activated from pub.dev, and generates the apps
/// with that `smf`: the apps with every module of that release, whose
/// modules may differ from those of the workspace. So the tool uses only
/// what `package:smf_flutter_cli/matrix.dart` has had since 0.3.0:
/// `matrixOf`, whose apps with every module are those with an
/// `everyModuleWith` in a release whose `MatrixApp` has it, and before
/// that the apps of the case `every module` of the contract harness, which
/// names after it the providers it picks. The apps of the other values of
/// the mode options are those with `modes`, in a release whose `MatrixApp`
/// has them; a release before that has no such app.
Future<void> main(List<String> arguments) async {
  if (arguments case [final directory] when !directory.startsWith('-')) {
    final (:apps, :failed) = await matrixOf(smfModules);
    for (final result in failed) {
      stderr.writeln('${result.contractCase}: ${result.errors.join('; ')}');
    }
    final everyModule = apps.where(_isEveryModule).toList();
    if (everyModule.isEmpty) {
      stderr.writeln('The matrix of smf create has no app with every module.');
    }
    if (failed.isNotEmpty || everyModule.isEmpty) {
      exitCode = 1;
      return;
    }
    stdout.writeln(
      jsonEncode([
        for (final (index, app) in everyModule.indexed)
          {
            'name': app.name,
            'arguments': [
              for (final argument
                  in app.createArguments('app_${index + 1}', directory))
                if (argument != '--no-dart-fix') argument,
            ],
          },
      ]),
    );
    return;
  }
  stderr.writeln('Usage: dart run tool/every_module_apps.dart <directory>');
  exitCode = 64;
}

/// Whether [app] is an app with every module: one with an
/// `everyModuleWith`, in a release whose `MatrixApp` has it, and otherwise
/// one of the case `every module` of the contract harness. An app with
/// `modes`, in a release whose `MatrixApp` has them, is the app of another
/// value of a mode option, and none of these.
bool _isEveryModule(MatrixApp app) {
  final mirror = reflect(app);
  final members = mirror.type.instanceMembers;
  if (members.containsKey(#modes) &&
      (mirror.getField(#modes).reflectee as Map).isNotEmpty) {
    return false;
  }
  if (members.containsKey(#everyModuleWith)) {
    return mirror.getField(#everyModuleWith).reflectee != null;
  }
  return app.name == 'every module' || app.name.startsWith('every module (');
}
